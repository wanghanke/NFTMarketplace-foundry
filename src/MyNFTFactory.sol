// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "./MyNFT.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyNFTFactory is Ownable{
    address public implementation;
    address[] private NFTs;
    mapping(address => address[]) private userNFT;

    event NFTCreated(address indexed nftAddress, address indexed creator, address indexed implementation);
    event ImplementationUpdated(address indexed oldImpl ,address indexed newImpl);

    constructor(address _implementation, address _owner) Ownable(_owner) {
        require(_implementation != address(0), "Invalid implementation");
        require(_implementation.code.length > 0, "Not contract");
        implementation = _implementation;
    }

    function createNFT(string calldata name, string calldata symbol) external returns(address) {
        require(implementation != address(0), "Implementation not set");
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, abi.encodeCall(MyNFT.initialize, (msg.sender, name, symbol)));

        NFTs.push(address(proxy));
        userNFT[msg.sender].push(address(proxy));

        emit NFTCreated(address(proxy), msg.sender, implementation);
        return address(proxy);
    }

    function getNFTCount() public view returns (uint256) {
        return NFTs.length;
    }

    function getNFT(uint256 index) public view returns(address) {
        return NFTs[index];
    }

    function getUserNFT(address user) public view returns(address[] memory) {
        return userNFT[user];
    }

    function setImplementation(address newImpl) external onlyOwner {
        require(newImpl != address(0), "Invalid implementation");
        require(newImpl.code.length > 0, "Not contract");

        address oldImpl = implementation;
        implementation = newImpl;
        emit ImplementationUpdated(oldImpl, newImpl);
    }
}
