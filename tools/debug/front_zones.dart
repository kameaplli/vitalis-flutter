const kFrontRegions = <BodyRegion>[

  // z1 -- R. Scalp
  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(364, 16),
      Offset(350, 20),
      Offset(334, 35),
      Offset(327, 54),
      Offset(332, 82),
      Offset(320, 84),
      Offset(323, 107),
      Offset(334, 108),
      Offset(347, 140),
      Offset(367, 153),
      Offset(367, 131),
      Offset(351, 124),
      Offset(354, 119),
      Offset(367, 122),
      Offset(367, 113),
      Offset(355, 108),
      Offset(358, 100),
      Offset(367, 104),
    ],
  ),

  // z2 -- L. Scalp
  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(382, 17),
      Offset(375, 17),
      Offset(375, 104),
      Offset(385, 100),
      Offset(387, 107),
      Offset(375, 113),
      Offset(375, 122),
      Offset(388, 120),
      Offset(390, 126),
      Offset(375, 131),
      Offset(375, 152),
      Offset(394, 138),
      Offset(407, 107),
      Offset(419, 112),
      Offset(426, 93),
      Offset(425, 86),
      Offset(413, 87),
      Offset(419, 61),
      Offset(411, 36),
    ],
  ),

  // z3 -- Neck
  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(453, 191),
      Offset(422, 171),
      Offset(402, 143),
      Offset(385, 158),
      Offset(370, 162),
      Offset(343, 151),
      Offset(330, 173),
      Offset(298, 189),
    ],
  ),

  // z4 -- R. Chest
  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(533, 243),
      Offset(519, 209),
      Offset(494, 194),
      Offset(387, 208),
      Offset(393, 195),
      Offset(310, 195),
      Offset(358, 196),
      Offset(364, 209),
      Offset(266, 194),
      Offset(236, 206),
      Offset(216, 247),
      Offset(269, 282),
      Offset(368, 282),
      Offset(371, 202),
      Offset(378, 282),
      Offset(476, 282),
    ],
  ),

  // z5 -- L. Chest
  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(533, 243),
      Offset(519, 209),
      Offset(494, 194),
      Offset(387, 208),
      Offset(393, 195),
      Offset(310, 195),
      Offset(358, 196),
      Offset(364, 209),
      Offset(266, 194),
      Offset(236, 206),
      Offset(216, 247),
      Offset(269, 282),
      Offset(368, 282),
      Offset(371, 202),
      Offset(378, 282),
      Offset(476, 282),
    ],
  ),

  // z6 -- R. Upper Arm
  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(219, 256),
      Offset(213, 256),
      Offset(178, 332),
      Offset(163, 355),
      Offset(175, 369),
      Offset(198, 378),
      Offset(210, 369),
      Offset(251, 311),
      Offset(259, 287),
      Offset(253, 273),
    ],
  ),

  // z7 -- L. Upper Arm
  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(490, 276),
      Offset(485, 282),
      Offset(485, 292),
      Offset(523, 346),
      Offset(546, 373),
      Offset(575, 363),
      Offset(582, 348),
      Offset(563, 300),
      Offset(536, 255),
    ],
  ),

  // z8 -- R. Forearm
  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(197, 386),
      Offset(170, 376),
      Offset(155, 364),
      Offset(136, 386),
      Offset(108, 452),
      Offset(78, 499),
      Offset(103, 508),
      Offset(171, 433),
    ],
  ),

  // z9 -- L. Forearm
  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(588, 359),
      Offset(577, 372),
      Offset(552, 384),
      Offset(579, 431),
      Offset(648, 502),
      Offset(672, 486),
      Offset(630, 425),
      Offset(611, 383),
    ],
  ),

  // z10 -- R. Hand
  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(101, 516),
      Offset(83, 513),
      Offset(70, 502),
      Offset(46, 514),
      Offset(33, 533),
      Offset(50, 527),
      Offset(55, 528),
      Offset(56, 533),
      Offset(48, 538),
      Offset(28, 575),
      Offset(50, 548),
      Offset(55, 548),
      Offset(56, 553),
      Offset(66, 553),
      Offset(62, 565),
      Offset(72, 558),
      Offset(74, 551),
      Offset(82, 552),
      Offset(91, 546),
      Offset(98, 534),
    ],
  ),

  // z11 -- L. Hand
  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(653, 509),
      Offset(655, 532),
      Offset(679, 560),
      Offset(685, 556),
      Offset(706, 580),
      Offset(692, 556),
      Offset(693, 549),
      Offset(706, 544),
      Offset(729, 574),
      Offset(726, 563),
      Offset(699, 528),
      Offset(706, 526),
      Offset(730, 542),
      Offset(737, 541),
      Offset(711, 513),
      Offset(680, 494),
    ],
  ),

  // z12 -- R. Upper Abd.
  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(369, 293),
      Offset(270, 293),
      Offset(282, 348),
      Offset(285, 416),
      Offset(294, 412),
      Offset(319, 384),
      Offset(345, 326),
      Offset(358, 313),
      Offset(368, 311),
    ],
  ),

  // z13 -- L. Upper Abd.
  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(377, 293),
      Offset(377, 310),
      Offset(388, 314),
      Offset(399, 326),
      Offset(423, 386),
      Offset(437, 403),
      Offset(453, 410),
      Offset(454, 370),
      Offset(475, 290),
    ],
  ),

  // z14 -- R. Lower Abd.
  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(368, 319),
      Offset(351, 332),
      Offset(327, 387),
      Offset(299, 418),
      Offset(284, 424),
      Offset(281, 456),
      Offset(287, 470),
      Offset(331, 512),
      Offset(366, 510),
    ],
  ),

  // z15 -- L. Lower Abd.
  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(377, 319),
      Offset(374, 511),
      Offset(417, 512),
      Offset(460, 470),
      Offset(456, 424),
      Offset(422, 400),
      Offset(390, 328),
    ],
  ),

  // z16 -- Groin
  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(339, 519),
      Offset(361, 554),
      Offset(373, 568),
      Offset(375, 568),
      Offset(392, 539),
      Offset(409, 521),
      Offset(409, 519),
    ],
  ),

  // z17 -- R. Thigh
  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(275, 470),
      Offset(265, 524),
      Offset(265, 592),
      Offset(276, 677),
      Offset(295, 733),
      Offset(318, 749),
      Offset(356, 744),
      Offset(369, 578),
      Offset(329, 522),
    ],
  ),

  // z18 -- L. Thigh
  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(464, 480),
      Offset(401, 541),
      Offset(378, 581),
      Offset(395, 744),
      Offset(431, 742),
      Offset(452, 722),
      Offset(474, 613),
      Offset(476, 561),
    ],
  ),

  // z19 -- R. Shin
  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(316, 815),
      Offset(297, 823),
      Offset(290, 840),
      Offset(309, 967),
      Offset(309, 1028),
      Offset(347, 1029),
      Offset(343, 988),
      Offset(358, 857),
      Offset(353, 826),
    ],
  ),

  // z20 -- L. Shin
  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(431, 812),
      Offset(389, 819),
      Offset(383, 842),
      Offset(383, 892),
      Offset(397, 944),
      Offset(398, 994),
      Offset(391, 1030),
      Offset(430, 1028),
      Offset(427, 989),
      Offset(442, 924),
      Offset(450, 840),
      Offset(448, 820),
    ],
  ),

  // z21 -- R. Foot
  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(349, 1037),
      Offset(307, 1036),
      Offset(293, 1058),
      Offset(269, 1085),
      Offset(289, 1087),
      Offset(291, 1093),
      Offset(303, 1086),
      Offset(308, 1096),
      Offset(307, 1106),
      Offset(317, 1104),
      Offset(328, 1084),
      Offset(350, 1061),
      Offset(352, 1047),
    ],
  ),

  // z22 -- L. Foot
  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(387, 1039),
      Offset(385, 1059),
      Offset(391, 1070),
      Offset(416, 1083),
      Offset(436, 1104),
      Offset(477, 1110),
      Offset(471, 1106),
      Offset(470, 1096),
      Offset(462, 1088),
      Offset(462, 1084),
      Offset(474, 1074),
      Offset(458, 1068),
      Offset(432, 1038),
      Offset(411, 1035),
    ],
  ),

  // z49 -- R. Knee
  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(296, 748),
      Offset(296, 813),
      Offset(315, 807),
      Offset(328, 807),
      Offset(353, 815),
      Offset(359, 773),
      Offset(358, 753),
      Offset(341, 758),
      Offset(319, 758),
    ],
  ),

  // z50 -- L. Knee
  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(449, 741),
      Offset(423, 753),
      Offset(390, 752),
      Offset(388, 810),
      Offset(414, 804),
      Offset(446, 807),
      Offset(444, 768),
    ],
  ),

];
