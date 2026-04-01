// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {OwnableUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {Initializable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC721Upgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {ERC721URIStorageUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

contract MyNFT is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable, ReentrancyGuard, PausableUpgradeable, UUPSUpgradeable{
    uint256 private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public mintPrice;

    event NFTMinted(address indexed owner, uint256 tokenId, string uri);
    event DrawnWithed(address indexed owner, uint256 balance);
    event MintPriceChanged(address indexed owner, uint256 oldPrice, uint256 newPrice);

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, string memory name, string memory symbol) public initializer {
        __Ownable_init(owner);
        __ERC721_init(name, symbol);
        __Pausable_init();
        maxSupply = 1000;
        mintPrice = 0.00001 ether;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintNFT(string memory uri) public payable nonReentrant whenNotPaused returns (uint256) {
        require(_tokenIdCounter < maxSupply, "Over maxSupply");
        require(msg.value >= mintPrice, "Insufficient payment");

        _tokenIdCounter++;
        _safeMint(msg.sender, _tokenIdCounter);
        _setTokenURI(_tokenIdCounter, uri);

        emit NFTMinted(msg.sender, _tokenIdCounter, uri);
        return _tokenIdCounter;
    }

    function withDrawn() public onlyOwner nonReentrant whenNotPaused {
        uint256 balance = address(this).balance;
        require(balance > 0, "Dont have balance");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "WithDrawn failed");

        emit DrawnWithed(owner(), balance);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns(string  memory) {
        return super.tokenURI(tokenId);
    }

    function getTotalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }

    function changeMintPrice(uint256 newPrice) public onlyOwner whenNotPaused {
        require(newPrice > 0, "Invalid newMintPrice");
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;

        emit MintPriceChanged(msg.sender, oldPrice, newPrice);
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    uint256[50] private __gap;
}
