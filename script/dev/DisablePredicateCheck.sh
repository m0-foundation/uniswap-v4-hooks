#!/bin/bash
source .env

cast rpc anvil_impersonateAccount $MANAGER
cast send $UNISWAP_HOOK \
	--from $MANAGER \
	"setPredicateCheck(bool)" \
	false \
	--unlocked
