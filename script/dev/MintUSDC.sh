#!/bin/bash
source .env

cast rpc anvil_impersonateAccount 0xF977814e90dA44bFA03b6295A0616a897441aceC
cast send 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 \
	--from 0xF977814e90dA44bFA03b6295A0616a897441aceC \
	"transfer(address,uint256)" \
	$RECIPIENT \
	10000000000000 \
	--unlocked
