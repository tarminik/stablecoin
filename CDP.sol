// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StableCoin.sol";

contract CDP {
    address public owner;
    uint256 public collateralizationRatio = 150; // 150%
    uint256 public stableCoinPrice = 1; // 1 stablecoin = 1 RUB
    uint256 public ethToRubPrice = 100; // Example ETH price in RUB

    struct Position {
        uint256 collateralETH;
        uint256 debtStableCoin;
    }

    mapping(address => mapping(uint256 => Position)) public userPositions; // user -> position ID -> Position
    mapping(address => uint256) public positionCount; // Tracks the number of positions for each user

    StableCoin public stableCoin;

    event CDPCreated(address indexed user, uint256 positionId, uint256 collateral, uint256 debt);
    event CDPRedeemed(address indexed user, uint256 positionId, uint256 collateral, uint256 repaidDebt);
    event Liquidated(address indexed user, uint256 positionId, uint256 collateralUsed);

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

        uint256 positionId = positionCount[msg.sender];
        userPositions[msg.sender][positionId] = Position({
            collateralETH: msg.value,
            debtStableCoin: maxMintable
        });

        positionCount[msg.sender]++;

        stableCoin.mint(msg.sender, maxMintable);

        emit CDPCreated(msg.sender, positionId, msg.value, maxMintable);
    }

    function redeemCDP(uint256 positionId, uint256 stableCoinAmount) external {
        Position storage position = userPositions[msg.sender][positionId];
        require(position.debtStableCoin >= stableCoinAmount, "Not enough debt to repay");

        uint256 collateralToReturn = (stableCoinAmount * collateralizationRatio * stableCoinPrice) / (100 * ethToRubPrice);
        require(position.collateralETH >= collateralToReturn, "Not enough collateral");

        position.debtStableCoin -= stableCoinAmount;
        position.collateralETH -= collateralToReturn;

        if (position.debtStableCoin == 0 && position.collateralETH == 0) {
            delete userPositions[msg.sender][positionId]; // Clean up if position is fully redeemed
        }

        stableCoin.burn(msg.sender, stableCoinAmount);
        payable(msg.sender).transfer(collateralToReturn);

        emit CDPRedeemed(msg.sender, positionId, collateralToReturn, stableCoinAmount);
    }

    function liquidate(address user, uint256 positionId) external {
        Position storage position = userPositions[user][positionId];

        uint256 requiredCollateral = (position.debtStableCoin * collateralizationRatio * stableCoinPrice) / (100 * ethToRubPrice);
        require(position.collateralETH < requiredCollateral, "Position is not undercollateralized");

        uint256 collateralUsed = position.collateralETH;
        position.collateralETH = 0;
        position.debtStableCoin = 0;

        delete userPositions[user][positionId]; // Remove the position after liquidation

        emit Liquidated(user, positionId, collateralUsed);
    }
}
