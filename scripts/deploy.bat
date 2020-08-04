@echo off
rem === DEFINE MODULES ===

SET EXT_TOKEN_DAI=0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa
SET EXT_COMPOUND_CTOKEN_DAI=0x6D7F0754FFeb405d23C51CE938289d4835bE3b14
SET EXT_COMPOUND_COMPTROLLER=0xD9580ad2bE0013A3a8187Dc29B3F63CDC522Bde7
SET EXT_CURVEFY_Y_DEPOSIT=0xE58e27F0D7aADF7857dbC50f9f471eFa54E15178
SET EXT_CURVEFY_Y_REWARDS=0x3a24cd58e76b11c5d8fd48215c721e8aa885b1d8
SET EXT_CURVEFY_SBTC_DEPOSIT=0xE639834AC3EBd7a24263eD5BdC38213bb4a8fdC6
SET EXT_CURVEFY_SBTC_REWARDS=0x69f60335b0ead20169ef3bfd94cce73ce03b8c3e
SET EXT_CURVEFY_SUSD_DEPOSIT=0x627E0ca4c14299ACE0383fC9CBb57634ef843499
SET EXT_CURVEFY_SUSD_REWARDS=0x716312d5176aC683953d54773B87A6001e449fD6

SET MODULE_POOL=0x13C90fe287E87c3D5ae724Bea954BA613f1876A3
SET MODULE_ACCESS=0xa462D92514C3f9F59BEf644f6dcF538Ac5cC447C
SET MODULE_SAVINGS=0xf4F0C0C49A953263bA29E619F760b3fd6dE60307

SET PROTOCOL_CURVEFY_Y=0x7DF81C45270AD4a07045Dadfe3C2F9e051179103
SET POOL_TOKEN_CURVEFY_Y=0xa9d89CEE1F406E8efF24c330Cd7F21751d94cA4b

SET PROTOCOL_CURVEFY_SBTC=0x1ddB207bE84a7d3206824c91C766e1F97254D68d
SET POOL_TOKEN_CURVEFY_SBTC=0x156B0dD8C7A26c8FAD42A48D1531cf03439a84f8

SET PROTOCOL_CURVEFY_SUSD=0xE1FF3e3Def9BfDD6116a7E57071B91C633E89FC7
SET POOL_TOKEN_CURVEFY_SUSD=0x98F88e11660e1E39FdE49388EDd454b6bD11895D

SET PROTOCOL_COMPOUND_DAI=0xF3b76e2280fB2789faBF53034FF146eCED141bcb
SET POOL_TOKEN_COMPOUND_DAI=0x0371A4B9F2A8110D174cFE895d0720ba1EcD7297

rem === ACTION ===
goto :setupContracts

:init
echo INIT PROJECT, ADD CONTRACTS
call npx oz init
call npx oz add Pool AccessModule SavingsModule
call npx oz add CurveFiProtocol_Y PoolToken_CurveFiY
call npx oz add CurveFiProtocol_SBTC PoolToken_CurveFi_SBTC
call npx oz add CurveFiProtocol_SUSD PoolToken_CurveFi_SUSD
call npx oz add CompoundProtocol_DAI PoolToken_Compound_DAI
goto :done

:createPool
echo CREATE POOL
call npx oz create Pool --network rinkeby --init
goto :done

:createModules
echo CREATE MODULES
call npx oz create AccessModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create SavingsModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE PROTOCOLS AND TOKENS
echo CREATE Curve.Fi Y
call npx oz create CurveFiProtocol_Y --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_Y --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi SBTC
call npx oz create CurveFiProtocol_SBTC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_SBTC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi SUSD
call npx oz create CurveFiProtocol_SUSD --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_SUSD --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Compound DAI
call npx oz create CompoundProtocol_DAI --network rinkeby --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_DAI%, %EXT_COMPOUND_CTOKEN_DAI%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_DAI --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:setupContracts
echo SETUP POOL: CALL FOR ALL MODULES (set)
rem npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "access, %MODULE_ACCESS%, false"
rem npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "savings, %MODULE_SAVINGS%, false"
echo SETUP OTHER CONTRACTS
echo call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_Y_DEPOSIT%, %EXT_CURVEFY_Y_REWARDS%"
rem DONE call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_SBTC_DEPOSIT%, %EXT_CURVEFY_SBTC_REWARDS%"
rem DONE call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_SUSD_DEPOSIT%, %EXT_CURVEFY_SUSD_REWARDS%"
rem DONE call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_COMPOUND_DAI%, %POOL_TOKEN_COMPOUND_DAI%"
echo call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_Y%, %POOL_TOKEN_CURVEFY_Y%"
rem DONE call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_SBTC%, %POOL_TOKEN_CURVEFY_SBTC%"
rem DONE call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_SUSD%, %POOL_TOKEN_CURVEFY_SUSD%"
goto :done

:setupOperators
echo SETUP PROTOCOLS
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
echo SETUP POOL TOKENS
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
goto :done

:done
echo DONE