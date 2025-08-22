#!/bin/bash
source .env

cast rpc anvil_impersonateAccount 0xfF95c5f35F4ffB9d5f596F898ac1ae38D62749c2
cast send 0x437cc33344a0B27A429f795ff6B469C72698B291 \
	--from 0xfF95c5f35F4ffB9d5f596F898ac1ae38D62749c2 \
	"transfer(address,uint256)" \
	$RECIPIENT \
	10000000000000 \
	--unlocked
