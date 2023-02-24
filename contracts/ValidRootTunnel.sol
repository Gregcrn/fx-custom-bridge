// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import {FxBaseRootTunnel} from '@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol';
import {Create2} from '@maticnetwork/fx-portal/contracts/lib/Create2.sol';
import {SafeERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * @title ValidRootTunnel
 */
contract ValidRootTunnel is FxBaseRootTunnel, Create2 {
    using SafeERC20 for IERC20;
    // maybe DEPOSIT and MAP_TOKEN can be reduced to bytes4 to save gas
    bytes32 public constant DEPOSIT = keccak256('DEPOSIT');
    bytes32 public constant MAP_TOKEN = keccak256('MAP_TOKEN');

    event TokenMappedERC20(
        address indexed rootToken,
        address indexed childToken
    );
    event FxWithdrawERC20(
        address indexed rootToken,
        address indexed childToken,
        address indexed userAddress,
        uint256 amount
    );
    event FxDepositERC20(
        address indexed rootToken,
        address indexed depositor,
        address indexed userAddress,
        uint256 amount
    );

    mapping(address => address) public rootToChildTokens;
    bytes32 public immutable childTokenTemplateCodeHash;

    constructor(
        address _checkpointManager,
        address _fxRoot,
        address _fxERC20Token
    ) FxBaseRootTunnel(_checkpointManager, _fxRoot) {
        // compute child token template code hash
        childTokenTemplateCodeHash = keccak256(
            minimalProxyCreationCode(_fxERC20Token)
        );
    }

    /**
     * @notice Map a token to enable its movement via the PoS Portal, callable by everyone
     * @param rootToken address of token on root chain
     */
    function mapToken(address rootToken) public {
        // check if token is already mapped
        require(
            rootToChildTokens[rootToken] == address(0x0),
            'ValidRootTunnel: ALREADY_MAPPED'
        );

        // name, symbol and decimals
        ERC20Permit rootTokenContract = ERC20Permit(rootToken);
        string memory name = rootTokenContract.name();
        string memory symbol = rootTokenContract.symbol();
        uint8 decimals = rootTokenContract.decimals();

        // MAP_TOKEN, encode(rootToken, name, symbol, decimals)
        bytes memory message = abi.encode(
            MAP_TOKEN,
            abi.encode(rootToken, name, symbol, decimals)
        );
        _sendMessageToChild(message);

        // compute child token address before deployment using create2
        bytes32 salt = keccak256(abi.encodePacked(rootToken));
        address childToken = computedCreate2Address(
            salt,
            childTokenTemplateCodeHash,
            fxChildTunnel
        );

        // add into mapped tokens
        rootToChildTokens[rootToken] = childToken;
        emit TokenMappedERC20(rootToken, childToken);
    }

    function deposit(
        address rootToken,
        address user,
        uint256 amount,
        bytes memory data,
        uint8 v, // v is the recovery byte, which is either 27 or 28
        bytes32 r, // r is the output of the ECDSA signature
        bytes32 s // s is the output of the ECDSA signature
    ) public {
        // map token if not mapped
        if (rootToChildTokens[rootToken] == address(0x0)) {
            mapToken(rootToken);
        }

        // transfer from depositor to this contract
        ERC20Permit(rootToken).transferFrom(
            msg.sender, // depositor
            address(this), // manager contract
            amount
        );
        // encode message
        bytes memory message = abi.encode(
            DEPOSIT,
            abi.encode(rootToken, user, amount, data, v, r, s)
        );

        // send message to child chain
        _sendMessageToChild(message);

        // emit event
        emit FxDepositERC20(rootToken, msg.sender, user, amount);
    }

    /**
     * @notice Get child token address mapped to a root token
     * @param rootToken address of token on root chain
     * @return child token address
     */
    function getChildToken(address rootToken) public view returns (address) {
        return rootToChildTokens[rootToken];
    }

    /**
     * @notice Checks if a token is already mapped
     * @param rootToken address of token on root chain
     * @return true if token is already mapped, otherwise false
     */
    function isTokenMapped(address rootToken) public view returns (bool) {
        return (rootToChildTokens[rootToken] != address(0x0));
    }

    /**
     * @notice Computes the child token address using create2
     * @param rootToken address of token on root chain
     * @return child token address
     */
    function computeChildTokenAddress(address rootToken)
        public
        view
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(rootToken));
        return
            computedCreate2Address(
                salt,
                childTokenTemplateCodeHash,
                fxChildTunnel
            );
    }

    function _processMessageFromChild(bytes memory data) internal override {
        (bytes32 syncType, bytes memory syncData) = abi.decode(
            data,
            (bytes32, bytes)
        );

        if (syncType == DEPOSIT) {
            (
                address rootToken,
                address depositor,
                address user,
                uint256 amount
            ) = abi.decode(syncData, (address, address, address, uint256));

            // transfer rootToken to this contract
            IERC20(rootToken).safeTransferFrom(
                depositor,
                address(this),
                amount
            );

            // transfer childToken to user on matic
            address childToken = rootToChildTokens[rootToken];
            IERC20(childToken).safeTransfer(user, amount);

            emit FxDepositERC20(rootToken, depositor, user, amount);
        } else {
            revert('ValidRootTunnel: INVALID_SYNC_TYPE');
        }
    }
}
