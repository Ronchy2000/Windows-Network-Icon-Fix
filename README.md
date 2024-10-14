## This repository addresses the issue where the Windows 10 network icon incorrectly shows as unconnected, even though you can successfully access the Internet.
win10电脑能上网但是图标显示未连接到网络（显示灰色小地球）的解决方法，这个问题应该只有中国大陆有。。。

## How to use
You can directly download the bat from release. <br>
1. Run the `modifyRegistryAndRestart.bat` in admin.<br>
2. Restart the `Windows network adapter` in `Network & Internet settings<br>

~1. Download this repo.~<br>
~2. Unzip the file.~<br>
~3. Run the `modifyRegistryAndRestart.bat` in admin.~ <br>
~4. Restart the `Windows network adapter` in `Network & Internet settings`~ <br>

---
More detail and reference:
> https://blog.csdn.net/Ronchy_2000/article/details/142069148
<br>and<br>
> https://blog.csdn.net/qq_45830323/article/details/129681354

---
简单说说，从Windows 10 1607版本开始，判断网络状态是通过让计算机访问这个网址：http://www.msftconnecttest.com/connecttest.txt，络连通情况下，浏览器访问这个URL返回的结果是文本Microsoft Connect Test。结果一致，网络图标就会是那个有网络的状态。

当然，不管正不正常，都不影响正常上网，它只是做了一次网络连通检测。我们完全可以把这个网址的dns解析切换成自己的私服ip，开放一个同样文案的文本即可。照样可以检测网络状态。

那么为什么最近会这样呢？查到的原因是：出自我国的几大网络运营商（ISP）。ISP们针对一些外国的IP地址做了一些限制。。。。 

 但所幸，Windows 10 1607之前的版本却是通过一个不同的URL（http://www.msftconnecttest.com/ncsi.txt）来完成认证的，而这个URL目前依然有效，且未被ISP屏蔽，所以上文给出的解决方案，就是恢复成这个url。

更深入的就不展开了。

另外，注册表中的这个字段，EnableActiveProbing，值为1意为开启探测，值为0意味关闭探测。
