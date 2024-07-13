// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FractionalizedNFT.sol";
import "./Interfaces/IFractionalizedNFT.sol";

contract FractionalizedNFTFactory is Ownable {
    event NFTDeployed(address nftAddress, string name, string symbol, IFractionalizedNFT.FractionType fractionType);

    address public rapidNodeAddress;

    constructor(address _rapidNodeAddress) {
        rapidNodeAddress = _rapidNodeAddress;
    }

    function deployNFT(
        string memory name,
        string memory symbol,
        uint256 saleStartTime,
        uint256 saleEndTime,
        address whitelistAddress,
        IFractionalizedNFT.FractionType fractionType
    ) external onlyOwner returns (address) {
        FractionalizedNFT newNFT = new FractionalizedNFT(
            name,
            symbol,
            saleStartTime,
            saleEndTime,
            rapidNodeAddress,
            whitelistAddress,
            fractionType
        );
        newNFT.transferOwnership(msg.sender);
        
        emit NFTDeployed(address(newNFT), name, symbol, fractionType);
        return address(newNFT);
    }

    function setRapidNodeAddress(address _rapidNodeAddress) external onlyOwner {
        rapidNodeAddress = _rapidNodeAddress;
    }
}