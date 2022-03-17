pragma solidity ^0.5.0;

import "./IKIP17.sol";
import "./IKIP7.sol";
import "./SafeMath.sol";
import "./String.sol";

contract Breeding {

  using String for string;
  using SafeMath for uint256;

  address private _mkcContract;
  address private _kongzContract;
  address private _babyContract;

  address private _admin;
  string  private _babyURI;
  uint256 private _breedingFee;
  uint256 private _breedingInterval;
  uint256 private _babyIndex;

  mapping (uint256 => uint256) private _breedingBlockNumber;

  event Breed(address addr, uint256 firstKongz, uint256 secondKongz);

  constructor (address kongzContract, address mkcContract, address babyContract) public {
    _admin = msg.sender;
    _babyIndex = 0;

    _kongzContract = kongzContract;
    _mkcContract = mkcContract;
    _babyContract = babyContract;
  }

  modifier onlyAdmin() {
    require(_admin == msg.sender, "only admin");
    _;
  }

  function setBreeding(uint256 breedingFee, uint256 breedingInterval, string calldata newBabyURI) external onlyAdmin {
    _breedingFee = breedingFee;
    _breedingInterval = breedingInterval;
    _babyURI = newBabyURI;
  }

  function renounce() external onlyAdmin {
    bool success;
    bytes memory data;
    (success, data) = _babyContract.call(abi.encodeWithSignature("renounceMinter()"));
  }

  function withdraw() external onlyAdmin {
    IKIP7 mkcToken = IKIP7(_mkcContract);
    uint256 totalValue = mkcToken.balanceOf(address(this));
    mkcToken.approve(address(this), totalValue);
    mkcToken.transferFrom(address(this), msg.sender, totalValue);
  }

  function getTimeStamp(uint256 kongz) view external returns(uint256[2] memory) {
    uint256[2] memory info = [_breedingBlockNumber[kongz], _breedingBlockNumber[kongz].add(_breedingInterval)];
    return info;
  }

  function breed(uint256 firstKongz, uint256 secondKongz) public {

    IKIP7 mkcToken = IKIP7(_mkcContract);
    IKIP17 kongzNFT = IKIP17(_kongzContract);

    uint256 current_block = block.number;
    require(mkcToken.balanceOf(msg.sender) >= _breedingFee, "lack of balance");
    require(current_block.sub(_breedingBlockNumber[firstKongz]) >= _breedingInterval, "not enough time has passed");
    require(current_block.sub(_breedingBlockNumber[secondKongz]) >= _breedingInterval, "not enough time has passed");
    address firstHolder = kongzNFT.ownerOf(firstKongz);
    address secondHolder = kongzNFT.ownerOf(secondKongz);

    require(msg.sender == firstHolder, "Not allowed(1)");
    require(msg.sender == secondHolder, "Not allowed(2)");

    _breedingBlockNumber[firstKongz] = block.number;
    _breedingBlockNumber[secondKongz] = block.number;

    uint256 allowance = mkcToken.allowance(msg.sender, address(this));
    require(allowance >= _breedingFee, "Check the token allowance");
    mkcToken.transferFrom(msg.sender, address(this), _breedingFee);

    //Mint
    bool success;
    bytes memory data;
    string memory metadata = string(abi.encodePacked(_babyURI, String.uint2str(_babyIndex),".json"));
    (success, data) = _babyContract.call(
        abi.encodeWithSignature(
          "mintWithTokenURI(address,uint256,string)", msg.sender, _babyIndex, metadata));
    if(!success){ revert(); }

    _babyIndex = _babyIndex.add(1);

    emit Breed(msg.sender, firstKongz, secondKongz);
  }
}
