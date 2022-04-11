// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/AccessControl.sol";


/**
 * @title  Vee system controller
 * @notice Implementation of contractor management .
 * @author Vee.Finance
 */

contract VeeSystemController is AccessControl {
    bytes32 public constant PROXY_ADMIN_ROLE = keccak256("PROXY_ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE    =  keccak256("EXECUTOR_ROLE");
    bytes32 public constant VEETOKEN_ROLE    =  keccak256("VEETOKEN_ROLE");
    bytes32 public constant PAUSEGUARDIAN_ROLE    =  keccak256("PAUSEGUARDIAN_ROLE");

    address internal constant VETH = address(1);

    address internal baseToken;

    // address internal pauseGuardian;

    enum VeeLockState { LOCK_CREATE, LOCK_EXECUTEDORDER, LOCK_CANCELORDER}

    
    /**
     * @dev Guard variable for re-entrancy checks
     */
    bool internal _notEntered;

    /**
     * @dev Lock All external functions
     * 0 unlock 1 lock
     */
    uint8 private _veeUnLockAll; 

    /**
     * @dev Lock createOrder
     * 0 unlock 1 lock
     */
    uint8 private _veeUnLockCreate; 

    /**
     * @dev Lock executeOrder
     * 0 unlock 1 lock
     */
    uint8 private _veeUnLockExecute; 

     /**
     * @dev Lock cancelOrder
     * 0 unlock 1 lock
     */
    uint8 private _veeUnLockCancel; 


    /**
     * @dev Lock the System
     * 0 unlock 1 lock
     */
    uint8 private _sysLockState;


    // address private _implementationAddress;

    /**
     * @dev Modifier throws if called methods have been locked by administrator.
     */
    modifier veeLock(uint8 lockType) {
        require(_sysLockState == 0,"veeLock: Lock System");
        require(_veeUnLockAll == 0,"veeLock: Lock All");

        if(lockType == uint8(VeeLockState.LOCK_CREATE)){
            require(_veeUnLockCreate == 0,"veeLock: Lock Create");
        }else if(lockType == uint8(VeeLockState.LOCK_EXECUTEDORDER)){
            require(_veeUnLockExecute == 0,"veeLock: Lock Execute");
        }else if(lockType == uint8(VeeLockState.LOCK_CANCELORDER)){
            require(_veeUnLockCancel == 0,"veeLock: Lock Cancel");
        }
        _;        
    }

    /**
     * @dev Modifier throws if called by any account other than the administrator.
     */
    modifier onlyAdmin() {
        require(hasRole(PROXY_ADMIN_ROLE, _msgSender()), "VeeSystemController: Admin permission required");
        _;
    }
    
    /**
     * @dev Modifier throws if called by any account other than the executor.
     */
    modifier onlyExecutor() {
        require(hasRole(EXECUTOR_ROLE, _msgSender()), "VeeSystemController: Executor permission required");
        _;
    }
 
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        require(_notEntered, "nonReentrant: Warning re-entered!");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }

     /**
     * @dev set state for locking some or all of functions or whole system.
     *
     * @param sysLockState     Lock whole system
     * @param veeUnLockAll     Lock all of functions
     * @param veeUnLockCreate  Lock create order
     * @param veeUnLockExecute Lock execute order
     *
     */
    function setState(uint8 sysLockState, uint8 veeUnLockAll, uint8 veeUnLockCreate, uint8 veeUnLockExecute, uint8 veeUnLockCancel) external {
        require(hasRole(PAUSEGUARDIAN_ROLE, msg.sender),"permission deny");
        _sysLockState       = sysLockState;
        _veeUnLockAll       = veeUnLockAll;
        _veeUnLockCreate    = veeUnLockCreate;
        _veeUnLockExecute   = veeUnLockExecute;
        _veeUnLockCancel    = veeUnLockCancel;
    }

    function setBaseToken(address _baseToken) external onlyAdmin {
        baseToken = _baseToken;
    }
    
}