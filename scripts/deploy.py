from brownie import GenesisBadge, accounts, SubscriptionService, NFTBoxesBox

def main():
	user = accounts.load('box', '\0')
	sub.setPrice(0, 1, {'from':user})
	sub.setPrice(1, 2, {'from':user})
	sub.setPrice(2, 3, {'from':user})
	

	gen = GenesisBadge.deploy({'from':user,'priority_fee':'3 gwei', 'max_fee':'80 gwei'}, publish_source=True)
	for i in range(10):
		gen.airdrop(50, {'from':user, 'priority_fee':'3 gwei', 'max_fee':'80 gwei'})

def deploy_rinkeby():
	user = accounts.load('box', '\0')

	sub = SubscriptionService.deploy("sub", "SUB", {'from':user}, publish_source=True)
	box = NFTBoxesBox.deploy(sub, {'from':user}, publish_source=True)
	box.setCaller(user, True,  {'from':user})

	for i in range(4):
		box.createBoxMould(500, 2, 0, [], [], "", "", "", "", "", {'from':user})
		box.setLockOnBox(i + 1, False,  {'from':user})

	sub.setPrice(0, 1, {'from':user})
	sub.setPrice(1, 2, {'from':user})
	sub.setPrice(2, 3, {'from':user})

	# sub.buySub(0, {'from':user})
	# sub.hasUserSub(user, 0)
