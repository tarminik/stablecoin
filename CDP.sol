// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StableCoin.sol";

contract CDP {
    address public owner;
    uint256 public collateralizationRatio = 150; // 150%
    uint256 public stableCoinPrice = 1; // 1 stablecoin = 1 RUB
    uint256 public ethToRubPrice = 100; // Example ETH price in RUB

    mapping(address => uint256) public collateralETH;
    mapping(address => uint256) public debtStableCoin;

    StableCoin public stableCoin;

    event CDPCreated(address indexed user, uint256 collateral, uint256 debt);
    event CDPRedeemed(address indexed user, uint256 collateral, uint256 repaidDebt);
    event Liquidated(address indexed user, uint256 collateralUsed);

    constructor(address _stableCoinAddress) {
        owner = msg.sender;
        stableCoin = StableCoin(_stableCoinAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function setEthToRubPrice(uint256 price) external onlyOwner {
        ethToRubPrice = price;
    }

    function createCDP() external payable {
        require(msg.value > 0, "Must deposit ETH");
        uint256 maxMintable = (msg.value * ethToRubPrice * 100) / (collateralizationRatio * stableCoinPrice);
        require(maxMintable > 0, "Insufficient collateral");

        collateralETH[msg.sender] += msg.value;
        debtStableCoin[msg.sender] += maxMintable;

        stableCoin.mint(msg.sender, maxMintable);

        emit CDPCreated(msg.sender, msg.value, maxMintable);
    }

    function redeemCDP(uint256 stableCoinAmount) external {
        require(debtStableCoin[msg.sender] >= stableCoinAmount, "Not enough debt to repay");

        uint256 collateralToReturn = (stableCoinAmount * collateralizationRatio * stableCoinPrice) / (100 * ethToRubPrice);
        require(collateralETH[msg.sender] >= collateralToReturn, "Not enough collateral");

        debtStableCoin[msg.sender] -= stableCoinAmount;
        collateralETH[msg.sender] -= collateralToReturn;

        stableCoin.burn(msg.sender, stableCoinAmount);
        payable(msg.sender).transfer(collateralToReturn);

        emit CDPRedeemed(msg.sender, collateralToReturn, stableCoinAmount);
    }

    function liquidate(address user) external {
        uint256 requiredCollateral = (debtStableCoin[user] * collateralizationRatio * stableCoinPrice) / (100 * ethToRubPrice);
        require(collateralETH[user] < requiredCollateral, "CDP is not undercollateralized");

        uint256 collateralUsed = collateralETH[user];
        collateralETH[user] = 0;
        debtStableCoin[user] = 0;

        emit Liquidated(user, collateralUsed);
    }
}
