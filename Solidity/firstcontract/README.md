# 部署第一个合约

# 钱包转账

 

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image.png)

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image 1.png)

# 部署第一个合约

创建一个 `counter.sol` 文件，写入 `Solidity` 代码，如下：

```solidity
//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Counter {
    uint256 internal count = 0;

    constructor() {}

    function get() public view returns (uint256) {
        return count;
    }

    function add(uint256 x) public {
        count += x;
    }
}
```

选择合适的编译器版本进行编译。

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%202.png)

在部署页面选择 `Injected Provider - MetaMask` ，这将使用MetaMask作为`Web3 Provider` ，可以通过MetaMask访问测试网。

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%203.png)

连接到MetaMask之后，选择部署合约的钱包账号地址，然后点击`Deploy` 发起交易进行部署。

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%204.png)

交易请求会自动打开MetaMask浏览器扩展进行确认。

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%205.png)

等待合约部署完成后就可以在Remix的控制台中看到交易信息。

![image.png](%E9%83%A8%E7%BD%B2%E7%AC%AC%E4%B8%80%E4%B8%AA%E5%90%88%E7%BA%A6%2019832b04c9d180b2beecc384dd5c4505/image%206.png)

复制交易信息中的`transaction hash` ，在**Sepolia**的区块链浏览器中查询交易hash就能找到刚刚部署的合约信息（[https://sepolia.etherscan.io/tx/0x7baea1a6d324c1b96c871bff86ff63ec911b850b46d8e27c21e38b1686c11ca7](https://sepolia.etherscan.io/tx/0x7baea1a6d324c1b96c871bff86ff63ec911b850b46d8e27c21e38b1686c11ca7)）。

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%207.png)

同样，在Remix中调用合约中的方法后也能通过交易信息中的`transaction hash` 查询到这笔交易信息（[https://sepolia.etherscan.io/tx/0xa75bb7ffef438ac94c35a7a502bb3661f7fe278b2edcfa7bec9d7e4f5019dd37](https://sepolia.etherscan.io/tx/0xa75bb7ffef438ac94c35a7a502bb3661f7fe278b2edcfa7bec9d7e4f5019dd37)）。

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%208.png)

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%209.png)

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%2010.png)

只有调用修改数据的函数会产生gas费，直接调用只读取数据的函数（被`view/pure` 修饰的函数）是不会产生gas费用的。例如下图中调用的get()方法，没有产生gas消耗，也没有交易hash。

![image.png](https://minio.drivefly.cn:443/image-hoshino/blog/2025/02/12/image%2011.png)