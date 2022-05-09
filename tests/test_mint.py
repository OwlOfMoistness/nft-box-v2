from brownie import Wei

def test_airdrop_some(nft_box, gen, accounts):
	owners = [nft_box.ownerOf(8 + (i * 10)) for i in range(500)]
	for i in range(10):
		gen.airdrop(50)

	for i in range(500):
		assert gen.ownerOf(i + 1) == owners[i]