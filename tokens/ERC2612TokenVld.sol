// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from '@maticnetwork/fx-portal/contracts/lib/ERC20.sol';
import {IFxERC20} from '@maticnetwork/fx-portal/contracts/tokens/IFxERC20.sol';
// import ERC20Burnable,ERC20Pausable and ERC20Permit from OpenZeppelin
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import {ERC20Pausable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';

contract ERC2612TokenVld is
    ERC20,
    IFxERC20,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Permit
{
    address internal _fxManager;
    address internal _connectedToken;

    function initialize(
        address fxManager_,
        address connectedToken_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public override {
        require(
            _fxManager == address(0x0) && _connectedToken == address(0x0),
            'Token is already initialized'
        );
        _fxManager = fxManager_;
        _connectedToken = connectedToken_;

        // setup meta data
        setupMetaData(name_, symbol_, decimals_);
    }

    // fxManager returns fx manager
    function fxManager() public view override returns (address) {
        return _fxManager;
    }

    // connectedToken returns root token
    function connectedToken() public view override returns (address) {
        return _connectedToken;
    }

    // setup name, symbol and decimals
    function setupMetaData(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public {
        require(msg.sender == _fxManager, 'Invalid sender');
        _setupMetaData(_name, _symbol, _decimals);
    }

    function mint(address user, uint256 amount) public override {
        require(msg.sender == _fxManager, 'Invalid sender');
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) public override {
        require(msg.sender == _fxManager, 'Invalid sender');
        _burn(user, amount);
    }
}
