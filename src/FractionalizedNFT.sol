// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Interfaces/IFractionalizedNFT.sol";
import "./Interfaces/IWhitelist.sol";

contract FractionalizedNFT is ERC721, Ownable, ReentrancyGuard, IFractionalizedNFT {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public saleStartTime;
    uint256 public saleEndTime;
    address public rapidNodeAddress;
    IWhitelist public whitelist;

    mapping(uint256 => FractionType) public tokenTypes;
    mapping(FractionType => uint256) public fractionPrices;
    mapping(FractionType => uint256) public fractionSupply;
    mapping(address => mapping(FractionType => uint256)) public userPurchases;

    uint256 public constant PLATINUM_FRACTION = 10;
    uint256 public constant GOLD_FRACTION = 20;
    uint256 public constant SILVER_FRACTION = 30;
    uint256 public constant PLATFORM_FEE = 0.2 ether; // $0.20 in wei

    uint256 public constant MAX_NODE_LICENSES = 500;
    uint256 public soldNodeLicenses;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _saleStartTime,
        uint256 _saleEndTime,
        address _rapidNodeAddress,
        address _whitelistAddress,
        uint256 _platinumPrice,
        uint256 _goldPrice,
        uint256 _silverPrice
    ) ERC721(name, symbol) {
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
        rapidNodeAddress = _rapidNodeAddress;
        whitelist = IWhitelist(_whitelistAddress);

        fractionPrices[FractionType.Platinum] = _platinumPrice;
        fractionPrices[FractionType.Gold] = _goldPrice;
        fractionPrices[FractionType.Silver] = _silverPrice;
    }

    function mint(FractionType fractionType) external payable override nonReentrant {
        require(block.timestamp >= saleStartTime && block.timestamp <= saleEndTime, "Sale is not active");
        require(whitelist.isWhitelisted(msg.sender), "Not whitelisted");
        require(whitelist.getRemainingMints(msg.sender) > 0, "No mints remaining");
        require(fractionSupply[fractionType] < getMaxSupply(fractionType), "Max supply reached for this fraction type");
        require(msg.value == fractionPrices[fractionType] + PLATFORM_FEE, "Incorrect payment amount");

        whitelist.decrementMints(msg.sender);
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        tokenTypes[newTokenId] = fractionType;
        fractionSupply[fractionType]++;
        userPurchases[msg.sender][fractionType]++;

        uint256 fractionValue = getFractionValue(fractionType);
        if (fractionSupply[fractionType] % fractionValue == 0) {
            soldNodeLicenses++;
        }
    }

    function burn(uint256 tokenId) external override {
        require(msg.sender == rapidNodeAddress, "Only RapidNode can burn tokens");
        FractionType fractionType = tokenTypes[tokenId];
        fractionSupply[fractionType]--;
        _burn(tokenId);
    }

    function refundUnsoldFractions() external nonReentrant {
        require(block.timestamp > saleEndTime, "Sale has not ended yet");
        require(soldNodeLicenses < MAX_NODE_LICENSES, "All node licenses sold");

        uint256 refundAmount = 0;
        for (uint256 i = 0; i < 3; i++) {
            FractionType fractionType = FractionType(i);
            uint256 userFractions = userPurchases[msg.sender][fractionType];
            if (userFractions > 0) {
                uint256 fractionValue = getFractionValue(fractionType);
                uint256 completeLicenses = fractionSupply[fractionType] / fractionValue;
                uint256 remainingFractions = fractionSupply[fractionType] % fractionValue;

                if (completeLicenses < MAX_NODE_LICENSES && userFractions <= remainingFractions) {
                    refundAmount += userFractions * (fractionPrices[fractionType] + PLATFORM_FEE);
                    fractionSupply[fractionType] -= userFractions;
                    userPurchases[msg.sender][fractionType] = 0;

                    for (uint256 j = 0; j < userFractions; j++) {
                        uint256 tokenId = _tokenIds.current();
                        if (ownerOf(tokenId) == msg.sender && tokenTypes[tokenId] == fractionType) {
                            _burn(tokenId);
                            _tokenIds.decrement();
                        }
                    }
                }
            }
        }

        require(refundAmount > 0, "No refund available");
        payable(msg.sender).transfer(refundAmount);
    }

    function setWhitelistContract(address _whitelistAddress) external onlyOwner {
        whitelist = IWhitelist(_whitelistAddress);
    }

    function getMaxSupply(FractionType fractionType) public pure returns (uint256) {
        if (fractionType == FractionType.Platinum) return MAX_NODE_LICENSES * PLATINUM_FRACTION;
        if (fractionType == FractionType.Gold) return MAX_NODE_LICENSES * GOLD_FRACTION;
        if (fractionType == FractionType.Silver) return MAX_NODE_LICENSES * SILVER_FRACTION;
        revert("Invalid fraction type");
    }

    function getFractionType(uint256 tokenId) external view returns (FractionType) {
        return tokenTypes[tokenId];
    }

    function getFractionPrice(FractionType fractionType) external view returns (uint256) {
        return fractionPrices[fractionType];
    }

    function getFractionValue(FractionType fractionType) public pure returns (uint256) {
        if (fractionType == FractionType.Platinum) return PLATINUM_FRACTION;
        if (fractionType == FractionType.Gold) return GOLD_FRACTION;
        if (fractionType == FractionType.Silver) return SILVER_FRACTION;
        revert("Invalid fraction type");
    }

    function withdrawFunds() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}