// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableCoin is ERC20 {
    address public cdpContract;

    constructor() ERC20("Ruble Stablecoin", "RUBSC") {
        cdpContract = msg.sender; // CDP contract is the minter
    }

    modifier onlyCDP() {
        require(msg.sender == cdpContract, "Only CDP contract can call this");
        _;
    }

    function mint(address to, uint256 amount) external onlyCDP {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyCDP {
        _burn(from, amount);
    }
}
