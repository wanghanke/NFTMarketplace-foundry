
# NFT拍卖市场合约


## 技术栈

- **solidity 0.8.28**
- **chainlink** 
- **openzeppelin**

## 项目结构

```
NFTMarketplace/
├── script/
│   └── deploy.s.sol                        # 部署脚本
│   ├── deployMyNFTUpgrade.s.sol            # NFT升级合约
│   ├── deployNFTAuctionUpgrade.s.sol       # Auction升级脚本
├── src/
│   ├── MyNFT.sol                           # NFT合约
│   ├── MyNFTFactory.sol                    # NFT工厂合约
│   ├── NFTAuction.sol                      # NFT拍卖合约
│   └── NFTAuction.sol                      # NFT拍卖合约工厂
├── test/
│   ├── MyNFT.sol                           # NFT合约测试用例
│   ├── MyNFTFactory.sol                    # NFT工厂合约测试用例
│   ├── NFTAuction.sol                      # NFT拍卖合约测试用例
│   └── NFTAuction.sol                      # NFT拍卖合约工厂测试用例
├── foundry.toml                            # foundry配置文件
└── README.md
```

## 使用流程
1、**NFT铸造**
   - 铸造调用`mintNFT(uri)`铸造NFT
   - 设置URI `tokenURI(tokenId)`
   - 取款 `withDrawn()`
   - 修改铸造NFT价格 `changeMintPrice(newPrice)`
   - 获取发行量 `getTotalSupply()`

2、**NFT拍卖**
   - 创建拍卖`createAuction(nftContract, currency, tokenId, startPrice, startTime, durationHours)`
   - 竞价 `bidAuction(auctionId, amount)`
   - 结束竞拍 `endAuction(auctionId)`
   - 取消竞拍 `cancelAuction(auctionId)`
   - 未竞拍成功者取款 `withdrawnBid(auctionId)`
   - 修改竞价最小增长率 `changeMinBidIncrementBps(_newBps)`
   - 修改平台费率 `changePlatformFeeBps(_newBps)`
   - 修改平台费率收款账号 `changePlatformFeeReceiver(_newReceiver)`
   - 设置预言机地址信息 `setPriceFeed(token, feed)`

3、**安装依赖**
```bash
forge install smartcontractkit/chainlink-brownie-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install Openzeppelin/contracts-upgradeable 
````

4、**部署命令**
```bash
forge script script/deploy.s.sol --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --slow
````
5、**部署地址**
- MyNFT implementation `0x9f9d69f6793d1f20479d3e5571743077E8B56c44`
- MyNFTFactory `0xA70d8a068BaC4Af5D0b565C739B958E99f7c6a3B`
- NFTAuction implementation `0xc71eA69a031b219CaB010848508a0325c19953c8`
- NFTAuctionFactory `0x424a7C3d0Df9b3eC82851A7A4925576957f4eBB0`
- Sample NFT proxy `0xB9eD1dC7Cc7b7282084d57bEF9f5D0da3Ad12e5C`
- Sample Auction proxy `0xA26f9Ca45752d452eEB9A9Ff39c1A4861DDA28E5`
