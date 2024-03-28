// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IHubErrors {
    error CirclesHubOnlyDuringBootstrap(uint8 code);

    error CirclesHubRegisterAvatarV1MustBeStopped(address avatar, uint8 code);

    error CirclesHubAvatarAlreadyRegistered(address avatar, uint8 code);

    error CirclesHubMustBeHuman(address avatar, uint8 code);

    error CirclesHubGroupIsNotRegistered(address group, uint8 code);

    error CirclesHubInvalidTrustReceiver(address trustReceiver, uint8 code);

    error CirclesHubGroupMintPolicyRejectedMint(
        address minter, address group, uint256[] collateral, uint256[] amounts, bytes data, uint8 code
    );

    error CirclesHubGroupMintPolicyRejectedBurn(address burner, address group, uint256 amount, bytes data, uint8 code);

    error CirclesHubOperatorNotApprovedForSource(address operator, address source, uint16 streamId, uint8 code);

    error CirclesHubCirclesAreNotTrustedByReceiver(address receiver, uint256 circlesId, uint8 code);

    error CirclesHubOnClosedPathOnlyPersonalCirclesCanReturnToAvatar(address failedReceiver, uint256 circlesId);

    error CirclesHubFlowVerticesMustBeSorted();

    error CirclesHubFlowEdgeStreamMismatch(uint16 flowEdgeId, uint16 streamId, uint8 code);

    error CirclesHubStreamMismatch(uint16 streamId, uint8 code);

    error CirclesHubNettedFlowMismatch(uint16 vertexPosition, int256 matrixNettedFlow, int256 streamNettedFlow);
}

interface ICirclesERC1155Errors {
    error CirclesERC1155MintBlocked(address human, address mintV1Status);

    error CirclesERC1155AmountExceedsMaxUint190(address account, uint256 circlesId, uint256 amount, uint8 code);
}

interface ICirclesErrors {
    error CirclesAvatarMustBeRegistered(address avatar, uint8 code);

    error CirclesAddressCannotBeZero(uint8 code);

    error CirclesInvalidFunctionCaller(address caller, address expectedCaller, uint8 code);

    error CirclesInvalidCirclesId(uint256 id, uint8 code);

    error CirclesInvalidString(string str, uint8 code);

    error CirclesInvalidParameter(uint256 parameter, uint8 code);

    error CirclesERC1155CannotReceiveBatch(uint8 code);

    error CirclesAmountOverflow(uint256 amount, uint8 code);

    error CirclesArraysLengthMismatch(uint256 lengthArray1, uint256 lengthArray2, uint8 code);

    error CirclesArrayMustNotBeEmpty(uint8 code);

    error CirclesAmountMustNotBeZero(uint8 code);

    error CirclesProxyAlreadyInitialized();

    error CirclesLogicAssertion(uint8 code);

    error CirclesIdMustBeDerivedFromAddress(uint256 providedId, uint8 code);
}

interface IStandardTreasuryErrors {
    error CirclesStandardTreasuryGroupHasNoVault(address group);

    error CirclesStandardTreasuryRedemptionCollateralMismatch(
        uint256 circlesId, uint256[] redemptionIds, uint256[] redemptionValues, uint256[] burnIds, uint256[] burnValues
    );

    error CirclesStandardTreasuryInvalidMetadataType(bytes32 metadataType, uint8 code);
}

interface INameRegistryErrors {
    error CirclesNamesInvalidName(address avatar, string name, uint8 code);

    error CirclesNamesShortNameAlreadyAssigned(address avatar, uint72 shortName, uint8 code);

    error CirclesNamesShortNameWithNonceTaken(address avatar, uint256 nonce, uint72 shortName, address takenByAvatar);

    error CirclesNamesAvatarAlreadyHasCustomNameOrSymbol(address avatar, string nameOrSymbol, uint8 code);

    error CirclesNamesOrganizationHasNoSymbol(address organization, uint8 code);
}
