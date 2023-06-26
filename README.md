# Giraffe ADC Temperature

Verilog repository based on INTEL-Quartus for ENOB of Giraffe ADC over temperature varying.

---

## 问题描述


- **在环境温度 / 芯片温度变化时，级间放大器的闭环增益 $G_{A}$ 应当是变化的**。因此需要周期性地进行Calibration，例如在完成**2pi**相位的采样之后进行1次Calibration测量增益；
- 但是由于数字部分FSM描述存在bug，在进行Calibration的时候仍然会对输入的模拟信号进行一次Sample，导致第一次D/A之后的电压结果不可控，这样的电压再进行x16的放大会直接超出测量范围，导致无法进行Calibration；

$$V_{out,DA_{1}} = V_{in,sampled} ~ \pm ~  V_{LSB}$$
- 该bug已在Falcon中消除；

## 解决方法

- ==使用SCPI指令实现对信号源（DS360）的控制与配置，基于INL、DNL测试开发的Quartus代码，控制ADC进行周期性的Calibration and Sample.==

整体工作流如下：

![](./img/Pasted-image-20230606214843.png)

![](./img/Pasted-image-20230606221614.png)

- 以MATLAB代码为核心实例DMM control + 2\*UART device for communicating with FPGA and DS360;
	- 由MATLAB控制整个测试系统的工作周期（以M次Calibration + N次Sample为一个周期），循环计数完成；
	- MATLAB先通过**UART0**对DS360进行配置，关闭输出，随后通过**UART1**给FPGA `calib_ena` 信号以及 `reset` 信号触发FPGA中FSM重置，控制Giraffe ADC采样。这随后的数据链不做赘述，需要注意的是Calibration的次数与Sample的次数需要分开；
	- 随后再通过**UART0**对DS360配置，打开输出，之后的操作同上；
	- 与所有的Calibration & Sample 并行的是DMM对PTAT进行测量。


### 可能遇到的BUG与TODO
- [x] FPGA的代码需要部分重构：
    - [x] 将 **FSM** 与顶层分开，使得顶层只有模块的实例化；
	- [x] 需要添加对`calib_ena`  `reset` 信号的reaction，目前只要是发送指令，不管是什么都会触发reset，没有区分度；
	- [x] 添加对Calibration 和 Sample 的次数控制reg；
- [x] UART0 控制DS360需要测试，目前没有只停留在理论可行阶段；
- [ ] 由于DMM的最低采样率为1kHz，因此关于温度的测量结果可能会远大于ADC的测量结果，**绘图结果的时候可能需要插值来实现对齐**；

### git ignore

```git
# .gitignore
output_files/*
db/*
greybox_temp/*
incremental_db/*
```

---

## 实验测试计划

1. Verilog 代码上版测试，不带温漂测试，测试RX、TX calibration和sample的基本功能；
2. 测试一次Calibration和一次Sample所需的时间，测量升温曲线速率；
3. 温度范围 27~125℃，温度间隔5℃，每个温度点做1次Calibration+10次Sample，取ENOB的平均值；

### 实验进度
- **20230620：** 完成对 Verilog 代码中 adc_rstn 信号出错的问题， 通过了 **UART Command** 使得状态转移的测试，预计 **0621** 完成 Verilog 代码验证；
- **20230625：** Verilog 代码完成，添加了 `UART_WAIT` 状态，能够在MATLAB发出控制指令之后等待0.1s再进行响应，具有更好的代码健壮性； 


# Giraffe ADC INL & DNL

基于 Temperature Sweep 的测试控制代码，搭建带有**随机时钟抖动**的 INL、DNL测试代码。

## 问题描述

用 matlab 生成信号模拟采样的信号，输入的 INL、DNL 的计算测试代码：
- 如果在每一分段的输入信号（33\*16Hz, 33/125000\*Fs）之间加入**随机相位**，由理想 16bitADC 量化，测得 INL、DNL 曲线正确，并且用该转移曲线量化我们的输入信号并做频谱分析，得到 SINAD 98dB 符合预期；
    
- 但是如果不加这个随机相位（正如我们的测试），在统计 Code 的时候就会报错，**实际得到的 Code 数量小于 2^16**。也就是说理想情况下: Fin = 33/125000*Fs 的这个输入信号频率选择本身就有问题，**无法满足 INL、DNL 的测试需求，无法遍历 16bit 所有的 CODE**。
    
- 但是由于 FPGA的片上 Memory 的空间有限，125000 个点几乎已经是单次测量的极限了；

## 解决方案

1. 通过逻辑门在输出的**时钟上面加随机延迟抖动**，以符合测试要求；
2. **使用USB-to-SPI模块**实现实时传输数据，所需的输入信号频率待仿真计算；