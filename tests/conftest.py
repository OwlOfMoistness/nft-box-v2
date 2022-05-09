import pytest

@pytest.fixture()
def nft_box(ERC721):
	return ERC721.at('0x6d4530149e5B4483d2F7E60449C02570531A0751')
@pytest.fixture()
def gen(GenesisBadge, accounts):
	return GenesisBadge.deploy({'from':accounts[0]})