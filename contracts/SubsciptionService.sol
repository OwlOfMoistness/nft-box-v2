pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SubscriptionService is ERC721("", ""), Ownable {

	struct SubData {
		uint32 start;
		uint32 length;
	}

	uint256 maxSupply = 500;
	bool paused;
	uint32 counter;

	uint256[3] public subPrices;
	uint256 buyCounter;

	mapping(uint256 => uint256) expiredStack;
	uint256 expiredCounter;
	mapping(uint256 => SubData) public subData;
	mapping(address => bool) public authorisedCaller;


	constructor() {
		subPrices[0] = 1_000_000_000_000_000_000;
		subPrices[1] = 2_000_000_000_000_000_000;
		subPrices[2] = 3_000_000_000_000_000_000;
		counter = 1;
	}

	modifier notPaused() {
		require(!paused, "Paused");
		_;
	}

	modifier authorised() {
		require(authorisedCaller[msg.sender], "Not authorised to execute.");
		_;
	}

	function setCaller(address _caller, bool _value) external onlyOwner {
		authorisedCaller[_caller] = _value;
	}

	function fetchEth() external onlyOwner {
		payable(owner()).transfer(address(this).balance);
	}

	function pause() external onlyOwner {
		paused = true;
	}

	function unpause() external onlyOwner {
		paused = false;
	}

	function pushNewBox() external authorised {
		counter++;
	}

	function setPrice(uint256 _index, uint256 _price) external onlyOwner {
		subPrices[_index] = _price;
	}

	function refundSub(uint256 _tokenId) external onlyOwner {
		require(!isExpired(_tokenId), "Expired");
		SubData memory data = subData[_tokenId];
		expiredStack[expiredCounter++] = _tokenId;
		delete subData[_tokenId];
		_burn(_tokenId);
	}

	function expireSub(uint256 _tokenId) external {
		require(isExpired(_tokenId), "Not expired");
		expiredStack[expiredCounter++] = _tokenId;
		delete subData[_tokenId];
		_burn(_tokenId);
	}

	// function overrideTransfer(uint256 _tokenId, address _newRecipient) external onlyOwner {
	// 	super._transfer(from, to, tokenId);
	// }

	function buySub(uint8 _type) external payable {
		buySub(_type, msg.sender);
	}

	function buySub(uint8 _type, address _for) public payable {
		require(_type == 0 || _type == 1 || _type == 2, "Sub: Wrong sub model");
		require(msg.value == subPrices[_type], "!price");
		if (buyCounter < maxSupply) {
			subData[buyCounter++] = SubData(counter, _getLength(_type));
			_mint(msg.sender, buyCounter);
		}
		else {
			require(expiredCounter > 0, "No subs available, try next month");
			uint256 id = expiredStack[--expiredCounter];
			subData[id] = SubData(counter, _getLength(_type));
			_mint(msg.sender, id);
		}
	}

	function isExpired(uint256 _tokenId) public view returns(bool) {
		SubData memory data = subData[_tokenId];
		return data.start + data.length < counter;
	}

	function _getType(uint32 _length) internal pure returns(uint256) {
		if (_length == 3)
			return 0;
		else if (_length == 6)
			return 1;
		if (_length == 9)
			return 2;
		return 0;
	}

	function _getLength(uint8 _type) internal pure returns(uint32) {
		if (_type == uint8(0))
			return uint32(3);
		else if (_type == uint8(1))
			return uint32(6);
		if (_type == uint8(2))
			return uint32(9);
		return 0;
	}

	function fetchValidHolders(uint256 _start, uint256 _len) external view returns(address[] memory holders) {
		for (uint256 i = _start; i < _start + _len; i++) {
			address owner = ownerOf(i);
			if (!isExpired(i))
				holders[i - _start] = ownerOf(i);
		}
	}

	function _transfer(address from, address to, uint256 tokenId) internal override notPaused {
		super._transfer(from, to, tokenId);
	}
}