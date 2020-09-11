pragma solidity ^0.5.12;

import "../modules/token/PoolToken.sol";
import "../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";

contract PoolToken_CurveFi_renBTC is PoolToken {
    function initialize(address _pool) public initializer {
        PoolToken.initialize(
            _pool, 
            "Delphi Curve renBTC",
            "drBTC"
        );
    }

    function burnFrom(address from, uint256 value) public {
        address investingModule = getModuleAddress(MODULE_INVESTING);
        if (_msgSender() == investingModule) {
            //Skip decrease allowance
            _burn(from, value);
        }else{
            super.burnFrom(from, value);
        }
    }

    function userBalanceChanged(address account) internal {
        IPoolTokenBalanceChangeRecipient investing = IPoolTokenBalanceChangeRecipient(getModuleAddress(MODULE_INVESTING));
        investing.poolTokenBalanceChanged(account);
    }

}