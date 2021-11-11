// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor () ERC20("Test Token", "TFaculty") {
        _mint(msg.sender, 500000 * (10 ** uint256(decimals())));
        _mint(address(this), 500000 * (10 ** uint256(decimals())));
    }
}