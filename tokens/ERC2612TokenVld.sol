// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title A title that should describe the contract/interface
/// @author GregCrn
/// @notice Create a simple ERC20, IFxERC20, ERC20Burnable, ERC20Pausable, ERC20Permit,

import {ERC20} from '@maticnetwork/fx-portal/contracts/lib/ERC20.sol';
import {IFxERC20} from '@maticnetwork/fx-portal/contracts/tokens/IFxERC20.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import {ERC20Pausable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
