# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update

# Deployment helpers
## Local
deploy-allowlist-hook-local :; FOUNDRY_PROFILE=production forge script script/deploy/DeployAllowlistHook.s.sol:DeployAllowlistHook --rpc-url localhost --broadcast -v
deploy-allowlist-hook-and-pool-local :; FOUNDRY_PROFILE=production forge script script/deploy/DeployAllowlistHookAndPool.s.sol:DeployAllowlistHookAndPool --rpc-url localhost --broadcast -v
deploy-tick-range-hook-local :; FOUNDRY_PROFILE=production forge script script/deploy/DeployTickRangeHook.s.sol:DeployTickRangeHook --rpc-url localhost --broadcast -v
deploy-tick-range-hook-and-pool-local :; FOUNDRY_PROFILE=production forge script script/deploy/DeployTickRangeHookAndPool.s.sol:DeployTickRangeHookAndPool --rpc-url localhost --broadcast -v

## Ethereum Mainnet
deploy-allowlist-hook-and-pool-ethereum :; FOUNDRY_PROFILE=production forge script script/deploy/DeployAllowlistHookAndPool.s.sol:DeployAllowlistHookAndPool --rpc-url mainnet --broadcast --verify -v

# Uniswap Pool Management helpers

## Ethereum Mainnet
add-liquidity-ethereum :; forge script script/dev/AddLiquidity.s.sol:AddLiquidity --rpc-url mainnet --broadcast -vvv
swap-ethereum :; forge script script/dev/Swap.s.sol:Swap --rpc-url mainnet --broadcast -vvv

## Local 
add-liquidity-local :; forge script script/dev/AddLiquidity.s.sol:AddLiquidity --rpc-url localhost --broadcast -vvv
swap-local :; forge script script/dev/Swap.s.sol:Swap --rpc-url localhost --broadcast -vvv

# Run slither
slither :; FOUNDRY_PROFILE=production forge build --build-info --skip '*/test/**' --skip '*/script/**' --force && slither --compile-force-framework foundry --ignore-compile --sarif results.sarif --config-file slither.config.json .

# Common tasks
profile ?=default

build:
	@./build.sh -p production

tests:
	@./test.sh -p $(profile)

fuzz:
	@./test.sh -t testFuzz -p $(profile)

integration:
	@./test.sh -d test/integration -p $(profile)

invariant:
	@./test.sh -d test/invariant -p $(profile)

coverage:
	FOUNDRY_PROFILE=$(profile) forge coverage --no-match-path "test/{deploy,fork}/**/*.t.sol" --report lcov && lcov --extract lcov.info -o lcov.info 'src/*' && genhtml lcov.info -o coverage

gas-report:
	FOUNDRY_PROFILE=$(profile) forge test --gas-report > gasreport.ansi

sizes:
	@./build.sh -p production -s

clean:
	forge clean && rm -rf ./abi && rm -rf ./bytecode && rm -rf ./types
