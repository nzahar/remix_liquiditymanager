// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityManager {
    address public owner;
    ISwapRouter public swapRouter;
    INonfungiblePositionManager public positionManager;

    IERC20 public token0; // BNDTIN
    IERC20 public token1; // USDT
    uint24 public poolFee;

    uint256 public tokenId;

    constructor(
        address _swapRouter,
        address _positionManager,
        address _token0,
        address _token1,
        uint24 _poolFee
    ) {
        owner = msg.sender;
        swapRouter = ISwapRouter(_swapRouter);
        positionManager = INonfungiblePositionManager(_positionManager);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        poolFee = _poolFee;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function adjustLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        int24 tickLower,
        int24 tickUpper
    ) external onlyOwner {
        // Approve tokens
        token0.approve(address(positionManager), amount0Desired);
        token1.approve(address(positionManager), amount1Desired);

        // Remove existing liquidity if tokenId exists
        if (tokenId != 0) {
            INonfungiblePositionManager.DecreaseLiquidityParams memory params =
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: type(uint128).max,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

            positionManager.decreaseLiquidity(params);

            // Collect the tokens from the position
            INonfungiblePositionManager.CollectParams memory collectParams =
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                });

            positionManager.collect(collectParams);

            // Burn the position
            positionManager.burn(tokenId);
        }

        // Add new liquidity
        INonfungiblePositionManager.MintParams memory mintParams =
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: poolFee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, , , ) = positionManager.mint(mintParams);
    }
}
