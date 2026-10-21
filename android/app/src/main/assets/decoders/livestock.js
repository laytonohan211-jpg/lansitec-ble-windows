/*
 * Shared LoRa and NTN product LoRaWAN uplink decoder.
 * GNSS bytes[1] and bytes[2] both zero: NTN accuracy; otherwise LoRa quality.
 * Compatible with ChirpStack v4, ChirpStack v3, TTN, and Node.js.
 */

var CODEC_VERSION = "5.4.0-unified";
var LIVESTOCK_FPORT = 8;

function byteToHex(value) {
    var text = (value & 0xFF).toString(16).toUpperCase();
    return text.length === 1 ? "0" + text : text;
}

function bytesToHex(bytes, start, end) {
    var parts = [];
    var i;

    for (i = start || 0; i < (end === undefined ? bytes.length : end); i++) {
        parts.push(byteToHex(bytes[i]));
    }
    return parts.join("");
}

function readUInt16BE(bytes, offset) {
    return (bytes[offset] & 0xFF) * 0x100 + (bytes[offset + 1] & 0xFF);
}

function readInt16BE(bytes, offset) {
    var value = readUInt16BE(bytes, offset);
    return value >= 0x8000 ? value - 0x10000 : value;
}

function readUInt32BE(bytes, offset) {
    return (
        (bytes[offset] & 0xFF) * 0x1000000 +
        (bytes[offset + 1] & 0xFF) * 0x10000 +
        (bytes[offset + 2] & 0xFF) * 0x100 +
        (bytes[offset + 3] & 0xFF)
    );
}

function readInt32BE(bytes, offset) {
    var value = readUInt32BE(bytes, offset);
    return value >= 0x80000000 ? value - 0x100000000 : value;
}

function readInt8(value) {
    return value >= 0x80 ? value - 0x100 : value;
}

function normalizeBytes(source, errors) {
    var bytes = [];
    var i;

    if (!source || typeof source.length !== "number") {
        errors.push("Missing bytes parameter");
        return bytes;
    }
    for (i = 0; i < source.length; i++) {
        if (
            typeof source[i] !== "number" ||
            source[i] < 0 ||
            source[i] > 255 ||
            source[i] % 1 !== 0
        ) {
            errors.push("bytes[" + i + "] is not a valid byte");
            return [];
        }
        bytes.push(source[i] & 0xFF);
    }
    return bytes;
}

function expectLength(bytes, expected, name, errors) {
    if (bytes.length !== expected) {
        errors.push(name + " length must be " + expected + " bytes; got " + bytes.length);
        return false;
    }
    return true;
}

function decodeRegister(bytes, data, errors) {
    if (!expectLength(bytes, 12, "Registration message", errors)) {
        return;
    }
    data.message_type = "register";
    data.adr_enabled = (bytes[0] & 0x01) !== 0;
    data.lorawan_data_rate = bytes[1] >> 4;
    data.tx_power_dbm = (bytes[1] & 0x0F) * 2;
    data.positioning_mode = bytes[2] >> 6;
    data.ble_enabled = (bytes[2] & 0x20) !== 0;
    data.gnss_enabled = (bytes[2] & 0x10) !== 0;
    data.asset_enabled = (bytes[2] & 0x08) !== 0;
    data.geofence_enabled = (bytes[2] & 0x04) !== 0;
    data.ble_gnss_independent = (bytes[2] & 0x02) !== 0;
    data.heartbeat_period_s = bytes[3] * 30;
    data.position_beacon_period_s = readUInt16BE(bytes, 4) * 5;
    data.gnss_period_s = readUInt16BE(bytes, 6) * 5;
    data.asset_period_s = readUInt16BE(bytes, 8) * 5;
    data.firmware_version_hex = "0x" + bytesToHex(bytes, 10, 12);
}

function decodeHeartbeat(bytes, data, warnings, errors) {
    var temperatureRaw;

    if (!expectLength(bytes, 7, "Heartbeat message", errors)) {
        return;
    }
    data.message_type = "heartbeat";
    data.battery_percent = bytes[1];
    data.alarm_status = bytes[2];
    data.low_battery_occurred = (bytes[2] & 0x80) !== 0;
    data.geofence_breach_occurred = (bytes[2] & 0x40) !== 0;
    data.abnormal_inactivity_occurred = (bytes[2] & 0x20) !== 0;
    data.high_intensity_motion_occurred = (bytes[2] & 0x10) !== 0;
    data.movement_duration_s = readUInt16BE(bytes, 3);
    temperatureRaw = readInt16BE(bytes, 5);
    data.temperature_raw_centi_c = temperatureRaw;
    data.temperature_valid = temperatureRaw !== -32768;
    if (data.temperature_valid) {
        data.temperature_c = temperatureRaw / 100;
    } else {
        warnings.push("Invalid temperature sensor reading");
    }
}

function decodeGnss(bytes, data, errors) {
    var longitudeE7;
    var latitudeE7;
    var hdopRaw;

    if (bytes.length !== 17) {
        errors.push("GNSS message length must be 17 bytes; got " + bytes.length);
        return;
    }
    data.message_type = "gnss_position";
    data.location_flag = bytes[0] & 0x0F;
    data.location_success = data.location_flag === 1;
    if (bytes[1] === 0 && bytes[2] === 0) {
        data.accuracy_m = readUInt32BE(bytes, 1) / 100;
    } else {
        data.satellites_visible = bytes[1] === 0xFF ? null : bytes[1];
        data.satellites_used = bytes[2] === 0xFF ? null : bytes[2];
        hdopRaw = readUInt16BE(bytes, 3);
        data.hdop = hdopRaw === 0xFFFF ? null : hdopRaw / 100;
    }
    longitudeE7 = readInt32BE(bytes, 5);
    latitudeE7 = readInt32BE(bytes, 9);
    data.longitude_e7 = longitudeE7;
    data.latitude_e7 = latitudeE7;
    data.longitude = longitudeE7 / 10000000;
    data.latitude = latitudeE7 / 10000000;
    data.timestamp_s = readUInt32BE(bytes, 13);
}

function decodeAssetRuleValue(bytes, start, end, errors) {
    var blockNames = {
        0x01: "adv_filter",
        0x02: "adv_report",
        0x03: "mac_report",
        0x04: "mac_filter"
    };
    var rule = { blocks: [] };
    var header;
    var blockCount;
    var offset;
    var i;

    if (start >= end) {
        errors.push("Asset Rule Value is empty");
        return rule;
    }
    header = bytes[start];
    rule.rule_id = (header >> 4) & 0x0F;
    blockCount = header & 0x0F;
    rule.block_count = blockCount;
    if (rule.rule_id !== 1 || blockCount === 0) {
        errors.push("Only Asset Rule ID 1 with at least one block is supported");
        return rule;
    }

    offset = start + 1;
    for (i = 0; i < blockCount; i++) {
        var type;
        var rangeStart;
        var rangeEnd;
        var maxIndex;
        var valueLength;
        var block;

        if (offset + 3 > end) {
            errors.push("Asset Rule block header is too short");
            return rule;
        }
        type = bytes[offset++];
        rangeStart = bytes[offset++];
        rangeEnd = bytes[offset++];
        if (!blockNames[type] || rangeStart > rangeEnd) {
            errors.push("Invalid Asset Rule block type or range");
            return rule;
        }
        maxIndex = (type === 0x03 || type === 0x04) ? 5 : 30;
        if (rangeEnd > maxIndex) {
            errors.push("Asset Rule block range exceeds the allowed bounds");
            return rule;
        }
        block = {
            type_id: type,
            type: blockNames[type],
            start: rangeStart,
            end: rangeEnd
        };
        if (type === 0x01 || type === 0x04) {
            valueLength = rangeEnd - rangeStart + 1;
            if (offset + valueLength > end) {
                errors.push("Asset Rule filter value is too short");
                return rule;
            }
            block.value_hex = bytesToHex(bytes, offset, offset + valueLength);
            offset += valueLength;
        }
        rule.blocks.push(block);
    }
    if (offset !== end) {
        errors.push("Asset Rule Value contains extra bytes");
    }
    return rule;
}

function decodeConfigResponse(bytes, data, warnings, errors) {
    var familyNames = {
        0x0A: "set_response",
        0x0B: "query_response",
        0x0C: "command_response",
        0x0D: "geofence_response"
    };
    var family = bytes[0] & 0x0F;
    var command;
    var count;
    var points;
    var i;
    var offset;

    if (bytes.length < 2 || !familyNames[family]) {
        errors.push("Invalid response type or length");
        return;
    }
    data.message_type = "config_response";
    data.response_type = familyNames[family];
    if (family === 0x0D) {
        if (!expectLength(bytes, 2, "Geofence setting response", errors)) {
            return;
        }
        data.point_count = bytes[1];
        return;
    }
    command = bytes[1];
    data.command_id = command;
    if (family !== 0x0B) {
        expectLength(bytes, 2, "Configuration or command response", errors);
        return;
    }

    data.value_hex = bytesToHex(bytes, 2);
    if (command === 0x30) {
        if (bytes.length < 3) {
            errors.push("Geofence query response is missing the point count");
            return;
        }
        count = bytes[2];
        if ((count !== 0 && count < 3) || count > 8 || bytes.length !== 3 + count * 8) {
            errors.push("Invalid point count or length in geofence query response");
            return;
        }
        points = [];
        for (i = 0; i < count; i++) {
            offset = 3 + i * 8;
            points.push({
                longitude_e7: readInt32BE(bytes, offset),
                latitude_e7: readInt32BE(bytes, offset + 4),
                longitude: readInt32BE(bytes, offset) / 10000000,
                latitude: readInt32BE(bytes, offset + 4) / 10000000
            });
        }
        data.point_count = count;
        data.points = points;
    } else if (
        command === 0x04 || command === 0x05 || command === 0x0B ||
        command === 0x10 || command === 0x11 || command === 0x12 ||
        command === 0x13 || command === 0x14
    ) {
        if (bytes.length !== 4) {
            errors.push("This query response value must be 2 bytes");
            return;
        }
        data.value = readUInt16BE(bytes, 2);
    } else if (command === 0x09) {
        if (bytes.length !== 18) {
            errors.push("UUID query response value must be 16 bytes");
            return;
        }
        data.uuid_hex = bytesToHex(bytes, 2);
    } else if (command === 0x0C) {
        data.asset_rule = decodeAssetRuleValue(bytes, 2, bytes.length, errors);
    } else {
        if (bytes.length !== 3) {
            errors.push("This query response value must be 1 byte");
            return;
        }
        data.value = command === 0x22 ? readInt8(bytes[2]) : bytes[2];
        if (command === 0x0E) data.ble_gnss_independent = bytes[2] === 1;
        if (command === 0x23) data.network_mode = ["lora", "ntn", "lora+ntn"][bytes[2]];
    }
}

function decodeBeacon(bytes, data, errors) {
    var count;
    var expected;
    var records = [];
    var offset;
    var i;

    if (bytes.length < 2) {
        errors.push("Beacon message must be at least 2 bytes");
        return;
    }

    count = bytes[1];
    expected = 2 + count * 5;
    if (bytes.length !== expected) {
        errors.push("Beacon count does not match the message length");
        return;
    }

    for (i = 0; i < count; i++) {
        offset = 2 + i * 5;
        records.push({
            major: readUInt16BE(bytes, offset),
            minor: readUInt16BE(bytes, offset + 2),
            rssi_dbm: readInt8(bytes[offset + 4])
        });
    }

    data.message_type = "beacon";
    data.beacon_count = count;
    data.beacons = records;
}

function decodeAssetRule(bytes, data, errors) {
    var count;
    var recordLength;
    var offset;
    var i;
    var records = [];

    if (bytes.length < 4) {
        errors.push("Asset Rule message must be at least 4 bytes");
        return;
    }
    count = bytes[1];
    if (count < 1 || count > 32 || (bytes.length - 2) % count !== 0) {
        errors.push("Asset Rule count does not match the message length");
        return;
    }
    recordLength = (bytes.length - 2) / count;
    if (recordLength < 2 || recordLength > 38) {
        errors.push("Asset Rule record length is out of range");
        return;
    }
    offset = 2;
    for (i = 0; i < count; i++) {
        records.push({
            data_hex: bytesToHex(bytes, offset, offset + recordLength - 1),
            rssi_dbm: readInt8(bytes[offset + recordLength - 1])
        });
        offset += recordLength;
    }
    data.message_type = "asset_rule";
    data.asset_count = count;
    data.assets = records;
}

function decodeAlarm(bytes, data, warnings, errors) {
    var alarmNames = {
        1: "low_battery",
        2: "geofence_breach",
        3: "abnormal_inactivity",
        4: "high_intensity_motion"
    };

    if (!expectLength(bytes, 2, "Alarm message", errors)) {
        return;
    }
    data.message_type = "alarm";
    data.alarm_id = bytes[1];
    data.alarm_type = alarmNames[bytes[1]] || "unknown";
    if (!alarmNames[bytes[1]]) {
        warnings.push("Unknown alarm type " + bytes[1]);
    }
}

function decodeUplink(input) {
    var result = { data: {}, warnings: [], errors: [] };
    var bytes = normalizeBytes(input && input.bytes, result.errors);
    var fPort = input && input.fPort;
    var type;

    result.data.codec_version = CODEC_VERSION;
    result.data.device_profile = "LIVESTOCK";
    result.data.f_port = fPort;
    result.data.payload_hex = bytesToHex(bytes);

    if (fPort !== undefined && fPort !== LIVESTOCK_FPORT) {
        result.warnings.push("Expected FPort 8; got " + fPort);
    }
    if (bytes.length === 0) {
        if (result.errors.length === 0) {
            result.errors.push("Uplink payload is empty");
        }
        return result;
    }

    if (bytes[0] === 0x80) {
        if (bytes.length < 7 || bytes.length > 22) {
            result.errors.push("History message length must be 7..22 bytes");
            return result;
        }
        result.data.is_history = true;
        result.data.age_s = readUInt32BE(bytes, 1);
        bytes = bytes.slice(5);
        if ([0x20, 0x30, 0x31, 0x40, 0x50].indexOf(bytes[0]) === -1) {
            result.errors.push("Unsupported history payload type");
            return result;
        }
        result.data.original_payload_hex = bytesToHex(bytes);
    }

    type = (bytes[0] >> 4) & 0x0F;
    result.data.message_type_id = type;
    switch (type) {
        case 0x01:
            decodeRegister(bytes, result.data, result.errors);
            break;
        case 0x02:
            decodeHeartbeat(bytes, result.data, result.warnings, result.errors);
            break;
        case 0x03:
            decodeGnss(bytes, result.data, result.errors);
            break;
        case 0x04:
            decodeBeacon(bytes, result.data, result.errors);
            break;
        case 0x05:
            decodeAlarm(bytes, result.data, result.warnings, result.errors);
            break;
        case 0x06:
            decodeConfigResponse(bytes, result.data, result.warnings, result.errors);
            break;
        case 0x07:
            decodeAssetRule(bytes, result.data, result.errors);
            break;
        default:
            result.data.message_type = "unknown";
            result.warnings.push("Unknown Livestock message type 0x" + byteToHex(type));
            break;
    }
    return result;
}

function Decode(fPort, bytes) {
    return decodeUplink({ fPort: fPort, bytes: bytes }).data;
}

function Decoder(bytes, port) {
    return Decode(port, bytes);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        decodeUplink: decodeUplink,
        Decode: Decode,
        Decoder: Decoder
    };
}

function decodeChecked(hex) { var bytes=[]; for(var i=0;i<hex.length;i+=2)bytes.push(parseInt(hex.substr(i,2),16)); return decodeUplink({fPort:8,bytes:bytes}); }
