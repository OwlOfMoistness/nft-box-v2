// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "../interfaces/IVendingMachine.sol";
import "@openzeppelin/contracts/access/Ownable.sol";	
import "./SubscriptionService.sol";
import "./BoxJsonParser.sol";


contract NFTBoxesBox is ERC721("NFTBox", "[BOX]"), Ownable, ERC2981, BoxJsonParser {
    
	struct BoxMould{
		uint8				live; // bool
		uint8				shared; // bool
		uint128				maxEdition;
		uint128				maxBuyAmount;
		uint128				currentEditionCount;
		uint256				price;
		address payable[]	artists;
		uint256[]			shares;
		string				name;
		string				series;
		string				theme;
		string				ipfsHash;
		string				arweaveHash;
	}

	struct Box {
		uint256				mouldId;
		uint256				edition;
	}

	uint256 totalSupply;
	IVendingMachine public	vendingMachine;
	SubscriptionService public subService;
	uint256 public			boxMouldCount;
	uint256 public			gasFee;

	uint256 constant public TOTAL_SHARES = 1000;
	uint256 constant DELIMITOR = 100000;

	mapping(uint256 => BoxMould) public	boxMoulds;
	mapping(uint256 =>  Box) public	boxes;
	mapping(uint256 => bool) public lockedBoxes;
	mapping(uint256 => mapping(address => uint256)) boxBoughtMapping;
	mapping(uint256 => uint256) subDistroTracker;

	mapping(address => uint256) public teamShare;
	address payable[] public team;

	string public baseUri;

	mapping(address => bool) public authorisedCaller;

	event BoxMouldCreated(uint256 id);
	event BoxBought(uint256 indexed boxMould, uint256 boxEdition, uint256 tokenId);
	event BatchDeployed(uint256 indexed boxMould, uint256 batchSize);

	constructor(address _service) {
		updateURI("https://nftboxesbox.azurewebsites.net/api/HttpTrigger?id=");
		gasFee = 1050;
		//boxMouldCount = 4;
		team.push(payable(0x3428B1746Dfd26C7C725913D829BE2706AA89B2e));
		team.push(payable(0x63a9dbCe75413036B2B778E670aaBd4493aAF9F3));
		team.push(payable(0x4C7BEdfA26C744e6bd61CBdF86F3fc4a76DCa073));
		team.push(payable(0xf521Bb7437bEc77b0B15286dC3f49A87b9946773));
		team.push(payable(0x3945476E477De76d53b4833a46c806Ef3D72b21E));
		team.push(payable(0xd084c5fF298E951E0e4CD29dD29684d5a54C0d8e));

		teamShare[address(0x3428B1746Dfd26C7C725913D829BE2706AA89B2e)] = 600;
        teamShare[address(0x63a9dbCe75413036B2B778E670aaBd4493aAF9F3)] = 10;
        teamShare[address(0x4C7BEdfA26C744e6bd61CBdF86F3fc4a76DCa073)] = 30;
        teamShare[address(0xf521Bb7437bEc77b0B15286dC3f49A87b9946773)] = 60;
        teamShare[address(0x3945476E477De76d53b4833a46c806Ef3D72b21E)] = 10;
        teamShare[address(0xd084c5fF298E951E0e4CD29dD29684d5a54C0d8e)] = 20;
		vendingMachine = IVendingMachine(0x6d4530149e5B4483d2F7E60449C02570531A0751);
		subService = SubscriptionService(_service);
	}


	function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return ERC2981.supportsInterface(interfaceId)
            || ERC721.supportsInterface(interfaceId);
    }

	function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyOwner {
		_setDefaultRoyalty(_receiver, _feeNumerator);
	} 

	function updateURI(string memory newURI) public onlyOwner {
		baseUri = newURI;
	}

	function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

	modifier authorised() {
		require(authorisedCaller[msg.sender] || msg.sender == owner(), "Not authorised to execute.");
		_;
	}

	function setCaller(address _caller, bool _value) external onlyOwner {
		authorisedCaller[_caller] = _value;
	}

	function addTeamMember(address payable _member) external onlyOwner {
		for (uint256 i = 0; i < team.length; i++)
			require( _member != team[i], "members exists already");
		team.push(_member);
	}

	function removeTeamMember(address payable _member) external onlyOwner {
		for (uint256 i = 0; i < team.length; i++)
			if (team[i] == _member) {
				delete teamShare[_member];
				team[i] = team[team.length - 1];
				team.pop();
			}
	}

	function setTeamShare(address _member, uint _share) external onlyOwner {
		require(_share <= TOTAL_SHARES, "share must be below 1000");
		for (uint256 i = 0; i < team.length; i++)
			if (team[i] == _member)
				teamShare[_member] = _share;
	}

	function setLockOnBox(uint256 _id, bool _lock) external authorised {
		require(_id <= boxMouldCount && _id > 0, "ID !exist.");
		lockedBoxes[_id] = _lock;
	}

	function createBoxMould(
		uint128 _max,
		uint128 _maxBuyAmount,
		uint256 _price,
		address payable[] memory _artists,
		uint256[] memory _shares,
		string memory _name,
		string memory _series,
		string memory _theme,
		string memory _ipfsHash,
		string memory _arweaveHash)
		external
		onlyOwner {
		require(_artists.length == _shares.length, "arrays !same len");
		boxMoulds[boxMouldCount + 1] = BoxMould({
			live: uint8(0),
			shared: uint8(0),
			maxEdition: _max,
			maxBuyAmount: _maxBuyAmount,
			currentEditionCount: 0,
			price: _price,
			artists: _artists,
			shares: _shares,
			name: _name,
			series: _series,
			theme: _theme,
			ipfsHash: _ipfsHash,
			arweaveHash: _arweaveHash
		});
		boxMouldCount++;
		lockedBoxes[boxMouldCount] = true;
		emit BoxMouldCreated(boxMouldCount);
	}

	function removeArtist(uint256 _id, address payable _artist) external onlyOwner {
		BoxMould storage boxMould = boxMoulds[_id];
		require(_id <= boxMouldCount && _id > 0, "ID !exist");
		for (uint256 i = 0; i < boxMould.artists.length; i++) {
			if (boxMould.artists[i] == _artist) {
				boxMould.artists[i] = boxMould.artists[boxMould.artists.length - 1];
				boxMould.artists.pop();
				boxMould.shares[i] = boxMould.shares[boxMould.shares.length - 1];
				boxMould.shares.pop();
			}
		}
	}
	
	function addArtists(uint256 _id, address payable _artist, uint256 _share) external onlyOwner {
		BoxMould storage boxMould = boxMoulds[_id];
		require(_id <= boxMouldCount && _id > 0, "ID !exist");
		boxMould.artists.push(_artist);
		boxMould.shares.push(_share);
	}

	function distributeBoxToSubHolders(uint256 _id) external onlyOwner {
		require(_id <= boxMouldCount && _id > 0, "ID !exist");
		uint256 trackerId = subDistroTracker[_id]++;
		require(trackerId < 6, "Distro done");

		BoxMould storage boxMould = boxMoulds[_id];
		uint128 currentEdition = boxMould.currentEditionCount;
		address[] memory subHolders = subService.fetchValidHolders(trackerId * 50, 50);
		uint256 mintTracker;
		uint256 _totalSupply = totalSupply;
		for (uint256 i = 0; i < 50; i++) {
			address holder = subHolders[i];
			if (holder != address(0)) {
				_buy(currentEdition, _id, mintTracker, holder, _totalSupply + mintTracker + 1);
				mintTracker++;
			}
		}
		totalSupply += mintTracker;
		boxMould.currentEditionCount += uint128(mintTracker);
		if (currentEdition + mintTracker == boxMould.maxEdition)
			boxMould.live = uint8(1);
		if (trackerId == 9)
			subService.pushNewBox();
	}

	function buyManyBoxes(uint256 _id, uint128 _quantity) external payable {
		BoxMould storage boxMould = boxMoulds[_id];
		uint128 currentEdition = boxMould.currentEditionCount;
		uint128 max = boxMould.maxEdition;
		require(_id <= boxMouldCount && _id > 0, "ID !exist");
		require(boxMould.live == 0, "!live");
		require(!lockedBoxes[_id], "locked");
		require(boxMould.price * _quantity == msg.value, "!price");
		require(currentEdition + _quantity <= max, "Too many boxes");
		require(boxBoughtMapping[_id][msg.sender] + _quantity <= boxMould.maxBuyAmount, "!buy");

		uint256 _totalSupply = totalSupply;
		for (uint128 i = 0; i < _quantity; i++)
			_buy(currentEdition, _id, i, msg.sender, _totalSupply + i + 1);
		totalSupply += _quantity;
		boxMould.currentEditionCount += _quantity;
		boxBoughtMapping[_id][msg.sender] = boxBoughtMapping[_id][msg.sender] + _quantity;
		if (currentEdition + _quantity == max)
			boxMould.live = uint8(1);
	}

	function _buy(uint128 _currentEdition, uint256 _id, uint256 _new, address _recipient, uint256 _tokenId) internal {
		boxes[_tokenId] = Box(_id, _currentEdition + _new + 1);
		//safe mint?
		emit BoxBought(_id, _currentEdition + _new + 1, _tokenId);
		_mint(_recipient, _tokenId);
	}

	// close a sale if not sold out
	function closeBox(uint256 _id) external authorised {
		BoxMould storage boxMould = boxMoulds[_id];
		require(_id <= boxMouldCount && _id > 0, "ID !exist.");
		boxMould.live = uint8(1);
	}

	function setVendingMachine(address _machine) external onlyOwner {
		vendingMachine = IVendingMachine(_machine);
	}

	function setGasFee(uint256 _fee) external onlyOwner {
		gasFee = _fee;
	}

	function distributeOffchain(uint256 _id, address[][] calldata _recipients, uint256[] calldata _ids) external authorised {
		BoxMould memory boxMould= boxMoulds[_id];
		require(boxMould.live == 1, "live");
		require (_recipients[0].length == _ids.length, "bad array");

		// i is batch number
		for (uint256 i = 0; i < _recipients.length; i++) {
			// j is for the index of nft ID to send
			for (uint256 j = 0;j <  _recipients[0].length; j++)
				vendingMachine.NFTMachineFor(_ids[j], _recipients[i][j]);
		}
		emit BatchDeployed(_id, _recipients.length);
	}

	function distributeShares(uint256 _id) external {
		BoxMould storage boxMould= boxMoulds[_id];
		require(_id <= boxMouldCount && _id > 0, "ID !exist.");
		require(boxMould.live == 1 && boxMould.shared == 0,  "!distribute");
		require(is100(_id), "sum != 100%.");

		boxMould.shared = 1;
		uint256 rev = uint256(boxMould.currentEditionCount) * boxMould.price;
		uint256 share;
		for (uint256 i = 0; i < team.length; i++) {
			share = rev * teamShare[team[i]] / TOTAL_SHARES;
			team[i].transfer(share);
		}
		for (uint256 i = 0; i < boxMould.artists.length; i++) {
			share = rev * boxMould.shares[i] / TOTAL_SHARES;
			boxMould.artists[i].transfer(share);
		}
	}

	function is100(uint256 _id) internal returns(bool) {
		BoxMould storage boxMould= boxMoulds[_id];
		uint256 total;
		for (uint256 i = 0; i < team.length; i++) {
			total = total + teamShare[team[i]];
		}
		for (uint256 i = 0; i < boxMould.shares.length; i++) {
			total = total + boxMould.shares[i];
		}
		return total == TOTAL_SHARES;
	}

	function getArtist(uint256 _id) external view returns (address payable[] memory) {
		return boxMoulds[_id].artists;
	}

	function getArtistShares(uint256 _id) external view returns (uint256[] memory) {
		return boxMoulds[_id].shares;
	}

    function getBoxMetaData(uint256 _id) external view returns 
    (uint256 boxId, uint256 boxEdition, uint128 boxMax, string memory boxName, string memory boxSeries, string memory boxTheme, string memory boxHashIPFS, string memory boxHashArweave) {
        Box memory box = boxes[_id];
        BoxMould memory mould = boxMoulds[box.mouldId];
        return (box.mouldId, box.edition, mould.maxEdition, mould.name, mould.series, mould.theme, mould.ipfsHash, mould.arweaveHash);
    }

	function _transfer(address from, address to, uint256 tokenId) internal override {
		Box memory box = boxes[tokenId];
		require(!lockedBoxes[box.mouldId], "Box is locked");
		super._transfer(from, to, tokenId);
	}

	function tokenURI(uint256 _tokenId) public view override returns(string memory) {
		Box memory box = boxes[_tokenId];
		require(box.mouldId > 0);
		BoxMould memory mould = boxMoulds[box.mouldId];
		return string(
			abi.encodePacked(
				generateTokenUriPart1(box.edition, mould.series, mould.name, mould.theme),
				generateTokenUriPart2(box.mouldId, box.edition, mould.maxEdition, mould.series, mould.ipfsHash, mould.theme)
			)
		);
	}

	function tokenURITest(uint256 _tokenId) public view returns(string memory) {

		return string(
			abi.encodePacked(
				generateTokenUriPart1(66, "Main", "December 2021", "Finale"),
				generateTokenUriPart2(12, 66, 132, "Main", "QmefbyT1uqjDaHsLzVMmwicjHVAXQjzfkeCXjfBwUA8om2", "Finale")
			)
		);
	}
}
