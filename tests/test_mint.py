from brownie import Wei, accounts, reverts

# def test_airdrop_some(nft_box, gen, accounts):
# 	owners = [nft_box.ownerOf(8 + (i * 10)) for i in range(500)]
# 	for i in range(10):
# 		gen.airdrop(50)

# 	for i in range(500):
# 		assert gen.ownerOf(i + 1) == owners[i]
def test_mint_sub(sub, accounts):
	for i in range(100):
		sub.buySub(0, {'from':accounts[0]})
		assert sub.ownerOf(i + 1) == accounts[0]
	with reverts('No more subs of that tier to buy'):
		sub.buySub(0, {'from':accounts[0]})

def test_expire_box(sub, accounts):
	sub.setCaller(accounts[0], True, {'from':accounts[0]})
	sub.pushNewBox({'fron':accounts[0]})
	sub.pushNewBox({'fron':accounts[0]})
	with reverts('Not expired'):
		sub.expireSub(1, {'from':accounts[0]})
	sub.pushNewBox({'fron':accounts[0]})
	sub.expireSub(1, {'from':accounts[0]})
	sub.buySub(0, {'from':accounts[0]})