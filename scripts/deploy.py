from brownie import GenesisBadge, accounts

def main():
	user = accounts.load('box', '\0')

	gen = GenesisBadge.deploy({'from':user,'priority_fee':'3 gwei', 'max_fee':'80 gwei'}, publish_source=True)
	for i in range(10):
		gen.airdrop(50, {'from':user, 'priority_fee':'3 gwei', 'max_fee':'80 gwei'})