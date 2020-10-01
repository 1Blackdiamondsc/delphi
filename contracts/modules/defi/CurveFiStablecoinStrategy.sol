pragma solidity ^0.5.12;

import "./VaultProtocol.sol";
import "../../interfaces/defi/IDefiStrategy.sol";
import "../../interfaces/defi/ICurveFiDeposit.sol";
import "../../interfaces/defi/ICurveFiDeposit_Y.sol";
import "../../interfaces/defi/ICurveFiLiquidityGauge.sol";
import "../../interfaces/defi/ICurveFiMinter.sol";
import "../../interfaces/defi/ICurveFiSwap.sol";

import "../../interfaces/defi/IUniswap.sol";

import "../../utils/CalcUtils.sol";

contract CurveFiStablecoinStrategy is VaultProtocol, IDefiStrategy {
    ICurveFiDeposit public curveFiDeposit;
    IERC20 public curveFiToken;
    ICurveFiLiquidityGauge public curveFiLPGauge;
    ICurveFiSwap public curveFiSwap;
    ICurveFiMinter public curveFiMinter;
    uint256 public slippageMultiplier;
    address public crvToken;
    address public wethToken; // used for crv <> weth <> dai route


    address public uniswapAddress;
    uint256 daiInd;

    //Register stablecoins contracts addresses
    function initialize(address _pool, address[] memory tokens, uint256 _daiInd) public initializer {
        VaultProtocol.initialize(_pool);
        for (uint256 i = 0; i < tokens.length; i++) {
            registeredVaultTokens.push(tokens[i]);
            claimableTokens.push(0);
        }

        slippageMultiplier = 1.01*1e18;

        daiInd = _daiInd;
    }

    function setProtocol(address _depositContract, address _liquidityGauge, address _curveFiMinter, address _uniswapAddress, address _wethToken) public onlyDefiOperator {
        require(_depositContract != address(0), "Incorrect deposit contract address");

        curveFiDeposit = ICurveFiDeposit(_depositContract);
        curveFiLPGauge = ICurveFiLiquidityGauge(_liquidityGauge);
        curveFiMinter = ICurveFiMinter(_curveFiMinter);
        curveFiSwap = ICurveFiSwap(curveFiDeposit.curve());

        curveFiToken = IERC20(curveFiDeposit.token());

        address lpToken = curveFiLPGauge.lp_token();
        require(lpToken == address(curveFiToken), "CurveFiProtocol: LP tokens do not match");

        crvToken = curveFiLPGauge.crv_token();

        uniswapAddress = _uniswapAddress;
        wethToken = _wethToken;
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        uint256[] memory amounts = new uint256[](registeredVaultTokens.length);
        uint256 ind = tokenRegisteredInd(token);

        for (uint256 i=0; i < registeredVaultTokens.length; i++) {
            amounts[i] = uint256(0);
        }
        amounts[ind] = amount;

        ICurveFiDeposit_Y(address(curveFiDeposit)).add_liquidity(convertArray(amounts), 0);
        
        uint256 cftBalance = curveFiToken.balanceOf(address(this));
        curveFiLPGauge.deposit(cftBalance);
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == amounts.length, "Count of tokens does not match count of amounts");
        require(amounts.length == registeredVaultTokens.length, "Amounts count does not match registered tokens");

        //Check for sufficient amounts on the Vault balances is checked in the WithdrawOperator()
        //Correct amounts are also set in WithdrawOperator()

        //Deposit stablecoins into the protocol
        ICurveFiDeposit_Y(address(curveFiDeposit)).add_liquidity(convertArray(amounts), 0);

        //Deposit yPool tokens into the y-pool to get CRV token
        uint256 cftBalance = curveFiToken.balanceOf(address(this));
        curveFiLPGauge.deposit(cftBalance);
    }

    function withdraw(address beneficiary, address token, uint256 amount) public onlyDefiOperator {
        uint256 tokenIdx = tokenRegisteredInd(token);

        //All withdrawn tokens are marked as claimable, so anyway we need to withdraw from the protocol

            // count shares for proportional withdraw
        uint256 nAmount = CalcUtils.normalizeAmount(token, amount);
        uint256 nBalance = normalizedBalance();

        uint256 poolShares = curveFiTokenBalance();
        uint256 withdrawShares = poolShares.mul(nAmount).mul(slippageMultiplier).div(nBalance).div(1e18); //Increase required amount to some percent, so that we definitely have enough to withdraw
            
        curveFiLPGauge.withdraw(withdrawShares);
        curveFiDeposit.remove_liquidity_one_coin(withdrawShares, int128(tokenIdx), amount, false); //DONATE_DUST - false

        IERC20 ltoken = IERC20(token);
        ltoken.safeTransfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        require(amounts.length == registeredVaultTokens.length, "Wrong amounts array length");

        //All withdrawn tokens are marked as claimable, so anyway we need to withdraw from the protocol
        uint256 nWithdraw;
        uint256 i;
        for (i = 0; i < registeredVaultTokens.length; i++) {
            address tkn = registeredVaultTokens[i];
            nWithdraw = nWithdraw.add(CalcUtils.normalizeAmount(tkn, amounts[i]));
        }

        uint256 nBalance = normalizedBalance();
        uint256 poolShares = curveFiTokenBalance();
        uint256 withdrawShares = poolShares.mul(nWithdraw).mul(slippageMultiplier).div(nBalance).div(1e18); //Increase required amount to some percent, so that we definitely have enough to withdraw

        curveFiLPGauge.withdraw(withdrawShares);
        ICurveFiDeposit_Y(address(curveFiDeposit)).remove_liquidity_imbalance(convertArray(amounts), withdrawShares);
        
        for (i = 0; i < registeredVaultTokens.length; i++){
            IERC20 lToken = IERC20(registeredVaultTokens[i]);
            uint256 lBalance = lToken.balanceOf(address(this));
            uint256 lAmount = (lBalance <= amounts[i])?lBalance:amounts[i]; // Rounding may prevent Curve.Fi to return exactly requested amount
            lToken.safeTransfer(beneficiary, lAmount);
        }
    }

    function performStrategy() public onlyDefiOperator {
        address dai = registeredVaultTokens[daiInd];

        claimRewardsFromProtocol();

        uint256 _crv = IERC20(crvToken).balanceOf(address(this));
        if (_crv > 0) {
            IERC20(crvToken).safeApprove(uniswapAddress, 0);
            IERC20(crvToken).safeApprove(uniswapAddress, _crv);

            address[] memory path = new address[](3);
            path[0] = crvToken;
            path[1] = wethToken;
            path[2] = dai;

            IUniswap(uniswapAddress).swapExactTokensForTokens(_crv, uint256(0), path, address(this), now.add(1800));
        }
        //new dai tokens will be transferred to this procol, they will be deposited by the operator on the next round
        //new LP tokens will be distributed automatically after the operator action
    }

    function curveFiTokenBalance() public view returns(uint256) {
        uint256 notStaked = curveFiToken.balanceOf(address(this));
        uint256 staked = curveFiLPGauge.balanceOf(address(this));
        return notStaked.add(staked);
    }

    function claimRewardsFromProtocol() internal {
        curveFiMinter.mint(address(curveFiLPGauge));
    }

    function balanceOf(address token) public returns(uint256) {
        uint256 tokenIdx = getTokenIndex(token);

        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();
        uint256 tokenCurveFiBalance = curveFiSwap.balances(int128(tokenIdx));
        
        return tokenCurveFiBalance.mul(cfBalance).div(cfTotalSupply);
    }

    function balanceOfAll() public returns(uint256[] memory balances) {
        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();

        balances = new uint256[](registeredVaultTokens.length);
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            uint256 tcfBalance = curveFiSwap.balances(int128(i));
            balances[i] = tcfBalance.mul(cfBalance).div(cfTotalSupply);
        }
    }

    function optimalProportions() public returns(uint256[] memory) {
        uint256[] memory amounts = balanceOfAll();
        uint256 summ;
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            amounts[i] = CalcUtils.normalizeAmount(registeredVaultTokens[i], amounts[i]);
            summ = summ.add(amounts[i]);
        }
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            amounts[i] = amounts[i].div(summ);
        }
        return amounts;
    }

    function normalizedBalance() public returns(uint256) {
        uint256[] memory balances = balanceOfAll();
        uint256 summ;
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            summ = summ.add(CalcUtils.normalizeAmount(registeredVaultTokens[i], balances[i]));
        }
        return summ;
    }

    function convertArray(uint256[] memory amounts) internal pure returns(uint256[4] memory) {
        require(amounts.length == 4, "Wrong token count");
        uint256[4] memory amnts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        for(uint256 i=0; i < 4; i++){
            amnts[i] = amounts[i];
        }
        return amnts;
    }

    function getTokenIndex(address token) public view returns(uint256) {
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            if (registeredVaultTokens[i] == token){
                return i;
            }
        }
        revert("CurveFiYProtocol: token not registered");
    }

//Stubs
    function canSwapToToken(address token) external view returns(bool) {
        return false;
    }

    function claimRewards() public returns(address[] memory tokens, uint256[] memory amounts) {
        tokens = new address[](1);
        amounts = new uint256[](1);
    }

    function withdrawReward(address token, address user, uint256 amount) public {

    }

    function supportedRewardTokens() external view returns(address[] memory) {
        address[] memory a = new address[](1);
        return a;
    }

    function isSupportedRewardToken(address token) external view returns(bool) {
        return false;
    }


}