![Darknet Logo](http://pjreddie.com/media/files/darknet-black-small.png) <img src="http://www.glitters20.com/quotes/wp-content/uploads/2012/12/Arrow-4.gif" width="100"> <img src="http://www.qualcomm.cn/sites/regional/files/styles/optimize/public/component-item/flexible-block/chip_0.png?itok=PpoXam0G" width="237">

# darknet on arm

An incomplete port of Darknet (and YOLO) to the Qualcomm® Snapdragon™ 820 processor using the Symphony System Manager SDK to better utilize the multicore CPU, GPU and DSP inside said processor.

This is a fork of Joseph Redmon *et al.* work on Darknet and the You only look once (YOLO) real-time object detection system.

You already have the config file for YOLO in the cfg/ subdirectory. To get started with YOLO you still need a pre-trained weight file. I recommend* creating a ./pre-trained/ directory and then downloading the following file made available by the original authors:
wget http://pjreddie.com/media/files/yolo.weights

*In fact, if you choose not to do this, you will have to edit the Makefile and darknet_run scripts by yourself.