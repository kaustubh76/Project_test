// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IWhitelist.sol";

contract Whitelist is IWhitelist, Ownable {
    mapping(address => uint256) private _whitelist;

    function setWhitelist(address[] memory users, uint256[] memory amounts) external onlyOwner {
        require(users.length == amounts.length, "Arrays must have the same length");
        for (uint256 i = 0; i < users.length; i++) {
            _whitelist[users[i]] = amounts[i];
        }
    }

    function isWhitelisted(address user) external view override returns (bool) {
        return _whitelist[user] > 0;
    }

    function getRemainingMints(address user) external view override returns (uint256) {
        return _whitelist[user];
    }

    function decrementMints(address user) external override {
        require(_whitelist[user] > 0, "No mints remaining");
        _whitelist[user]--;
    }
}