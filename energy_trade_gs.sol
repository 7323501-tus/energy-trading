// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

contract Trading16 {
    address public owner;
    uint256 public ContractPrice = 0;
    uint256 public tradeCount = 0;  // dealCount
    uint256 public totalTradeVolume = 0;  // Total traded kWh
    uint256 public totalProsumerSum = 0;
    uint256 public totalConsumerSum = 0;

    // tradeVolumeごとの回数をカウントするための配列
    uint[26] public tradeVolumeCount; // tradeVolumeが0~25を対象 (インデックス0は使わない)

    event DicisionContractPrice(uint256 ContractPrice);
    event TradeExecuted(uint consumerNumber, uint prosumerNumber, uint256 tradeVolume);
    event TradeVolumeCounted(uint volume, uint count); // tradeVolumeごとの回数を出力するイベント

    modifier onlyOwner() {
        require(owner == msg.sender, "only owner!");
        _;
    }

    address consumeraddress;
    address prosumeraddress;
    struct Consumer {
        address consumer;           // consumer Hash値
        uint256 number;             // consumer id
        uint256 kwh;                // consumer kwh
        uint256 value;              // consumer value
        uint256 sum;                // consumer sum 
    }

    struct Prosumer {
        address prosumer;
        uint256 number;                 
        uint256 kwh;
        uint256 value;
        uint256 sum;       
    }

    Consumer[] public consumerList;
    Prosumer[] public prosumerList;

    uint[] public matchConsumer;    // MatchingResult (Consumer -> Prosumer)
    uint[] public matchProsumer;    // MatchingResult (Prosumer -> Consumer)

    constructor() {
        owner = msg.sender;
        consumeraddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        prosumeraddress = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    }

    function pushConsumer(uint256 number, uint256 kwh, uint256 value) public onlyOwner returns (uint256) {
        consumerList.push(Consumer(consumeraddress, number, kwh, value, 0));
        return consumerList.length - 1;
    }

    function pushProsumer(uint256 number, uint256 kwh, uint256 value) public onlyOwner returns (uint256) {
        prosumerList.push(Prosumer(prosumeraddress, number, kwh, value, kwh));
        return prosumerList.length - 1;
    }

    ////////////////////////////////////////////////////
    //Create Consumer by Gaussian distribution
    function C100ConsumerData(uint steps) public {
        Consumer[] memory consumerresult = new Consumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.number, loop, idx)));
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Consumer memory newconsumer = Consumer(consumeraddress, number, kwh, value, 0); 
                consumerresult[sum + idx] = newconsumer;
            }
            sum += endpoint[loop];
        }

        for (uint i = 0; i < consumerresult.length; i++) {
            consumerList.push(consumerresult[i]);
        }
    }

    //Create Prosumer by Gaussian distribution
    function C100ProsumerData(uint steps) public {
        Prosumer[] memory prosumerresult = new Prosumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.timestamp, block.number, loop, idx)));
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Prosumer memory newprosumer = Prosumer(prosumeraddress, number, kwh, value, kwh); 
                prosumerresult[sum + idx] = newprosumer;
            }
            sum += endpoint[loop];
        }

        for (uint j = 0; j < prosumerresult.length; j++) {
            prosumerList.push(prosumerresult[j]);
        }
    }

    //Create Consumer by Gaussian distribution
    function C10ConsumerData(uint steps) public {
        Consumer[] memory consumerresult = new Consumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.number, loop, idx)));
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Consumer memory newconsumer = Consumer(consumeraddress, number, kwh, value, 0); 
                consumerresult[sum + idx] = newconsumer;
                number++; 
            }
            sum += endpoint[loop];
        }
        for (uint i = 0; i < consumerresult.length; i++) {
            consumerList.push(consumerresult[i]);
        }
    }
    
    // Create Prosumer by Gaussian distribution
    function C10ProsumerData(uint steps) public {
        Prosumer[] memory prosumerresult = new Prosumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpoint.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.number, loop, idx)));
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Prosumer memory newprosumer = Prosumer(prosumeraddress, number, kwh, value, kwh); 
                prosumerresult[sum + idx] = newprosumer;
                number++; 
            }
            sum += endpoint[loop];
        }
        for (uint i = 0; i < prosumerresult.length; i++) {
            prosumerList.push(prosumerresult[i]);
        }
    }

    ///////////////////////////////////////////////////////
    // Gale-Shapley Algorithm
    function galeShapley() public onlyOwner {
        uint consumerCount = consumerList.length;
        uint prosumerCount = prosumerList.length;

        matchConsumer = new uint[](consumerCount);
        matchProsumer = new uint[](prosumerCount);

        for (uint i = 0; i < consumerCount; i++) {
            matchConsumer[i] = type(uint).max;
        }

        for (uint i = 0; i < prosumerCount; i++) {
            matchProsumer[i] = type(uint).max;
        }

        // matching-bestPair
        for (uint i = 0; i < consumerCount; i++) {
            Consumer storage consumer = consumerList[i];
            uint bestProsumerIndex = type(uint).max;
            uint bestProsumerDiff = type(uint).max;

            for (uint j = 0; j < prosumerCount; j++) {
                Prosumer storage prosumer = prosumerList[j];
                if (consumer.value >= prosumer.value && matchProsumer[j] == type(uint).max) {
                    uint diff = absDiff(consumer.kwh, prosumer.sum);
                    if (diff == 0) {
                        // finish
                        bestProsumerIndex = j;
                        break; 
                    }
                    if (diff < bestProsumerDiff || (diff == bestProsumerDiff && prosumer.value < prosumerList[bestProsumerIndex].value)) {
                        bestProsumerDiff = diff;
                        bestProsumerIndex = j;
                    }
                }
            }
            if (bestProsumerIndex != type(uint).max) {
                matchConsumer[i] = bestProsumerIndex;
                matchProsumer[bestProsumerIndex] = i;
            }
        }
    }

    function absDiff(uint a, uint b) internal pure returns (uint) {
        return a > b ? a - b : b - a;
    }
    
    function executeTrade() public {
        uint consumerCount = consumerList.length;
        for (uint i = 0; i < consumerCount; i++) {
            if (matchConsumer[i] != type(uint).max) {
                uint prosumerIndex = matchConsumer[i];

                Consumer storage consumer = consumerList[i];
                Prosumer storage prosumer = prosumerList[prosumerIndex];

                uint256 tradeVolume = consumer.kwh < prosumer.sum ? consumer.kwh : prosumer.sum;
                consumer.kwh -= tradeVolume;
                consumer.sum += tradeVolume;
                prosumer.sum -= tradeVolume;
                tradeCount++;
                totalTradeVolume += tradeVolume;

                // tradeVolumeが1～25の場合、対応するカウンターをインクリメント
                if (tradeVolume > 0 && tradeVolume <= 25) {
                    tradeVolumeCount[tradeVolume]++;
                }

                emit TradeExecuted(consumer.number, prosumer.number, tradeVolume);
            }

        }
        // Calculate total prosumer sum
        for (uint i = 0; i < prosumerList.length; i++) {
            totalProsumerSum += prosumerList[i].sum;
        }
        // tradeVolumeごとの回数を出力する
        outputTradeVolumeCounts();
    }

    // tradeVolumeごとの回数を出力する関数
    function outputTradeVolumeCounts() internal {
        for (uint i = 1; i <= 25; i++) {
            emit TradeVolumeCounted(i, tradeVolumeCount[i]);
        }
    }
    
    // Consumer Counting-sort by value 
    function countingSortConsumersDesc() public {
        uint256 maxValue = 19; 
        uint256[] memory count = new uint256[](maxValue + 1);
        Consumer[] memory sorted = new Consumer[](consumerList.length);

        for (uint i = 0; i < consumerList.length; i++) {
            count[consumerList[i].value]++;
        }
        for (uint i = maxValue; i > 0; i--) {
            count[i - 1] += count[i];
        }
        for (int i = int(consumerList.length) - 1; i >= 0; i--) {
            Consumer storage consumer = consumerList[uint(i)];
            uint index = count[consumer.value] - 1;
            
            while (index > 0 && sorted[index - 1].value == consumer.value && sorted[index - 1].kwh < consumer.kwh) {
                sorted[index] = sorted[index - 1];
                index--;
            }
            sorted[index] = consumer;
            count[consumer.value]--;
        }
        for (uint i = 0; i < consumerList.length; i++) {
            consumerList[i] = sorted[i];
        }
    }

    // Prosumer Counting-sort by value 
    function countingSortProsumersAsc() public {
        uint256 maxValue = 19;
        uint256[] memory count = new uint256[](maxValue + 1);
        Prosumer[] memory sorted = new Prosumer[](prosumerList.length);

        for (uint i = 0; i < prosumerList.length; i++) {
            count[prosumerList[i].value]++;
        }
        for (uint i = 1; i <= maxValue; i++) {
            count[i] += count[i - 1];
        }
        for (int i = int(prosumerList.length) - 1; i >= 0; i--) {
            Prosumer storage prosumer = prosumerList[uint(i)];
            uint index = count[prosumer.value] - 1;

            while (index > 0 && sorted[index - 1].value == prosumer.value && sorted[index - 1].kwh < prosumer.kwh) {
                sorted[index] = sorted[index - 1];
                index--;
            }
            sorted[index] = prosumer;
            count[prosumer.value]--;
        }
        for (uint i = 0; i < prosumerList.length; i++) {
            prosumerList[i] = sorted[i];
        }
    }
}