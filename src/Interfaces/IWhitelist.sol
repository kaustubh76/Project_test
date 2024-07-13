// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFractionalizedNFT {
    enum FractionType { Gold, Silver, Platinum }

    function mint() external;
    function burn(uint256 tokenId) external;
}