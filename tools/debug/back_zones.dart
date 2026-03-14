const kBackRegions = <BodyRegion>[

  // z23 -- R. Scalp (B)
  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1127, 78),
      Offset(1127, 131),
      Offset(1136, 130),
      Offset(1150, 124),
      Offset(1149, 117),
      Offset(1152, 114),
      Offset(1152, 78),
    ],
  ),

  // z24 -- L. Scalp (B)
  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1158, 78),
      Offset(1158, 114),
      Offset(1161, 117),
      Offset(1160, 124),
      Offset(1174, 130),
      Offset(1183, 131),
      Offset(1183, 78),
    ],
  ),

  // z25 -- Nape
  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1265, 191),
      Offset(1229, 165),
      Offset(1223, 151),
      Offset(1223, 133),
      Offset(1203, 140),
      Offset(1180, 140),
      Offset(1160, 134),
      Offset(1152, 162),
      Offset(1114, 187),
    ],
  ),

  // z26 -- L. Upper Back
  BodyRegion(
    id: 'z26', label: 'L. Upper Back', number: 26, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1033, 274),
      Offset(1069, 292),
      Offset(1125, 278),
      Offset(1062, 275),
      Offset(1136, 272),
      Offset(1184, 245),
      Offset(1185, 200),
      Offset(1073, 198),
      Offset(1049, 222),
      Offset(1053, 275),
      Offset(1047, 275),
      Offset(1044, 232),
    ],
  ),

  // z27 -- R. Upper Back
  BodyRegion(
    id: 'z27', label: 'R. Upper Back', number: 27, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1194, 199),
      Offset(1193, 243),
      Offset(1222, 251),
      Offset(1252, 270),
      Offset(1257, 200),
    ],
  ),

  // z28 -- L. Upper Arm (B)
  BodyRegion(
    id: 'z28', label: 'L. Upper Arm (B)', number: 28, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(937, 309),
      Offset(921, 355),
      Offset(931, 369),
      Offset(950, 379),
      Offset(956, 379),
      Offset(966, 368),
      Offset(942, 365),
      Offset(970, 362),
      Offset(1011, 303),
      Offset(982, 296),
      Offset(961, 274),
    ],
  ),

  // z29 -- R. Upper Arm (B)
  BodyRegion(
    id: 'z29', label: 'R. Upper Arm (B)', number: 29, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1349, 274),
      Offset(1328, 296),
      Offset(1299, 303),
      Offset(1340, 362),
      Offset(1368, 365),
      Offset(1344, 368),
      Offset(1354, 379),
      Offset(1360, 379),
      Offset(1379, 369),
      Offset(1389, 355),
      Offset(1373, 309),
    ],
  ),

  // z30 -- L. Forearm (B)
  BodyRegion(
    id: 'z30', label: 'L. Forearm (B)', number: 30, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(884, 404),
      Offset(858, 469),
      Offset(839, 500),
      Offset(854, 515),
      Offset(863, 516),
      Offset(867, 500),
      Offset(915, 446),
      Offset(947, 389),
      Offset(916, 366),
    ],
  ),

  // z31 -- R. Forearm (B)
  BodyRegion(
    id: 'z31', label: 'R. Forearm (B)', number: 31, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1394, 366),
      Offset(1363, 389),
      Offset(1395, 446),
      Offset(1443, 500),
      Offset(1447, 516),
      Offset(1456, 515),
      Offset(1471, 500),
      Offset(1452, 469),
      Offset(1426, 404),
    ],
  ),

  // z32 -- L. Hand (B)
  BodyRegion(
    id: 'z32', label: 'L. Hand (B)', number: 32, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(913, 510),
      Offset(888, 526),
      Offset(861, 555),
      Offset(886, 545),
      Offset(867, 594),
      Offset(887, 560),
      Offset(893, 567),
      Offset(885, 584),
      Offset(898, 568),
      Offset(904, 570),
      Offset(889, 603),
      Offset(905, 576),
      Offset(911, 579),
      Offset(908, 592),
      Offset(916, 585),
      Offset(941, 534),
    ],
  ),

  // z33 -- R. Hand (B)
  BodyRegion(
    id: 'z33', label: 'R. Hand (B)', number: 33, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1369, 534),
      Offset(1394, 585),
      Offset(1402, 592),
      Offset(1399, 579),
      Offset(1405, 576),
      Offset(1421, 603),
      Offset(1406, 570),
      Offset(1412, 568),
      Offset(1425, 584),
      Offset(1417, 567),
      Offset(1423, 560),
      Offset(1443, 594),
      Offset(1424, 545),
      Offset(1449, 555),
      Offset(1422, 526),
      Offset(1397, 510),
    ],
  ),

  // z34 -- L. Mid Back
  BodyRegion(
    id: 'z34', label: 'L. Mid Back', number: 34, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1185, 278),
      Offset(1141, 278),
      Offset(1100, 299),
      Offset(1091, 319),
      Offset(1101, 367),
      Offset(1159, 367),
      Offset(1175, 355),
      Offset(1185, 340),
    ],
  ),

  // z35 -- R. Mid Back
  BodyRegion(
    id: 'z35', label: 'R. Mid Back', number: 35, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1193, 278),
      Offset(1194, 339),
      Offset(1219, 365),
      Offset(1230, 367),
      Offset(1231, 374),
      Offset(1274, 395),
      Offset(1295, 318),
      Offset(1288, 301),
      Offset(1247, 276),
    ],
  ),

  // z36 -- L. Lower Back
  BodyRegion(
    id: 'z36', label: 'L. Lower Back', number: 36, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1088, 373),
      Offset(1088, 447),
      Offset(1097, 447),
      Offset(1097, 405),
      Offset(1093, 373),
    ],
  ),

  // z37 -- R. Lower Back
  BodyRegion(
    id: 'z37', label: 'R. Lower Back', number: 37, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1193, 373),
      Offset(1193, 438),
      Offset(1203, 447),
      Offset(1225, 447),
      Offset(1228, 450),
      Offset(1225, 453),
      Offset(1210, 453),
      Offset(1221, 463),
      Offset(1275, 462),
      Offset(1272, 404),
      Offset(1244, 392),
      Offset(1216, 373),
    ],
  ),

  // z38 -- L. Buttock
  BodyRegion(
    id: 'z38', label: 'L. Buttock', number: 38, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1104, 473),
      Offset(1090, 526),
      Offset(1087, 562),
      Offset(1094, 578),
      Offset(1108, 591),
      Offset(1128, 597),
      Offset(1152, 595),
      Offset(1155, 577),
      Offset(1158, 594),
      Offset(1177, 587),
      Offset(1190, 574),
      Offset(1190, 515),
      Offset(1155, 472),
      Offset(1136, 467),
    ],
  ),

  // z39 -- R. Buttock
  BodyRegion(
    id: 'z39', label: 'R. Buttock', number: 39, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1275, 471),
      Offset(1242, 468),
      Offset(1226, 472),
      Offset(1199, 508),
      Offset(1199, 573),
      Offset(1226, 587),
      Offset(1247, 587),
      Offset(1270, 578),
      Offset(1285, 565),
      Offset(1290, 551),
    ],
  ),

  // z40 -- L. Thigh (B)
  BodyRegion(
    id: 'z40', label: 'L. Thigh (B)', number: 40, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1020, 665),
      Offset(1048, 807),
      Offset(1085, 807),
      Offset(1085, 813),
      Offset(1060, 813),
      Offset(1099, 817),
      Offset(1111, 586),
      Offset(1063, 595),
      Offset(1018, 571),
    ],
  ),

  // z41 -- R. Thigh (B)
  BodyRegion(
    id: 'z41', label: 'R. Thigh (B)', number: 41, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1292, 571),
      Offset(1247, 595),
      Offset(1199, 586),
      Offset(1211, 817),
      Offset(1250, 813),
      Offset(1225, 813),
      Offset(1225, 807),
      Offset(1262, 807),
      Offset(1290, 665),
    ],
  ),

  // z42 -- L. Calf
  BodyRegion(
    id: 'z42', label: 'L. Calf', number: 42, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1041, 868),
      Offset(1046, 917),
      Offset(1093, 920),
      Offset(1046, 923),
      Offset(1063, 1023),
      Offset(1093, 1029),
      Offset(1093, 967),
      Offset(1106, 907),
      Offset(1097, 826),
      Offset(1047, 819),
    ],
  ),

  // z43 -- R. Calf
  BodyRegion(
    id: 'z43', label: 'R. Calf', number: 43, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1263, 819),
      Offset(1213, 826),
      Offset(1204, 907),
      Offset(1217, 967),
      Offset(1217, 1029),
      Offset(1247, 1023),
      Offset(1264, 923),
      Offset(1217, 920),
      Offset(1264, 917),
      Offset(1269, 868),
    ],
  ),

  // z44 -- L. Foot (B)
  BodyRegion(
    id: 'z44', label: 'L. Foot (B)', number: 44, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1101, 1072),
      Offset(1087, 1070),
      Offset(1094, 1086),
      Offset(1084, 1093),
      Offset(1066, 1093),
      Offset(1060, 1085),
      Offset(1062, 1071),
      Offset(1071, 1066),
      Offset(1055, 1060),
      Offset(1006, 1066),
      Offset(998, 1072),
      Offset(1000, 1081),
      Offset(1013, 1090),
      Offset(1051, 1095),
      Offset(1083, 1105),
      Offset(1095, 1103),
      Offset(1103, 1088),
    ],
  ),

  // z45 -- R. Foot (B)
  BodyRegion(
    id: 'z45', label: 'R. Foot (B)', number: 45, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1207, 1088),
      Offset(1215, 1103),
      Offset(1227, 1105),
      Offset(1259, 1095),
      Offset(1297, 1090),
      Offset(1310, 1081),
      Offset(1312, 1072),
      Offset(1304, 1066),
      Offset(1255, 1060),
      Offset(1239, 1066),
      Offset(1248, 1071),
      Offset(1250, 1085),
      Offset(1244, 1093),
      Offset(1226, 1093),
      Offset(1216, 1086),
      Offset(1223, 1070),
      Offset(1209, 1072),
    ],
  ),

  // z46 -- Sacrum
  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1104, 473),
      Offset(1090, 526),
      Offset(1087, 562),
      Offset(1094, 578),
      Offset(1108, 591),
      Offset(1128, 597),
      Offset(1152, 595),
      Offset(1155, 577),
      Offset(1158, 594),
      Offset(1177, 587),
      Offset(1190, 574),
      Offset(1190, 515),
      Offset(1155, 472),
      Offset(1136, 467),
    ],
  ),

  // z47 -- L. Back Knee
  BodyRegion(
    id: 'z47', label: 'L. Back Knee', number: 47, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1041, 868),
      Offset(1046, 917),
      Offset(1093, 920),
      Offset(1046, 923),
      Offset(1063, 1023),
      Offset(1093, 1029),
      Offset(1093, 967),
      Offset(1106, 907),
      Offset(1097, 826),
      Offset(1047, 819),
    ],
  ),

  // z48 -- R. Back Knee
  BodyRegion(
    id: 'z48', label: 'R. Back Knee', number: 48, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1263, 819),
      Offset(1213, 826),
      Offset(1204, 907),
      Offset(1217, 967),
      Offset(1217, 1029),
      Offset(1247, 1023),
      Offset(1264, 923),
      Offset(1217, 920),
      Offset(1264, 917),
      Offset(1269, 868),
    ],
  ),

];
