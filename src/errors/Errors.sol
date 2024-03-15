// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IHubErrors {}

interface ICirclesErrors {
    error CirclesInvalidFunctionCaller(address caller, uint8 code);

    error CirclesInvalidCirclesId(uint256 id, uint8 code);

    error CirclesERC1155CannotReceiveBatch(uint8 code);

    error CirclesAmountOverflow(uint256 amount, uint8 code);
}
