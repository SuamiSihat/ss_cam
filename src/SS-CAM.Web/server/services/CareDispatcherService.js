const BranchService = require('./BranchService');

class CareDispatcherService {
  constructor() {
    this.protocols = {
      eswt: {
        id: 'eswt',
        name: 'Terapi Gelombang Kejutan (ESWT)',
        englishName: 'Extracorporeal Shockwave Therapy (ESWT)',
        immediateGuidelines: [
          'Rehat secukupnya dalam tempoh 24–48 jam pertama; elakkan senaman berat.',
          'Kekal terhidrasi dengan minum sekurang-kurangnya 2.5 liter air kosong sehari.',
          'ELAKKAN pengambilan ubat tahan sakit anti-radang (NSAIDs seperti Ibuprofen/Voltaren) kerana ia boleh merencatkan proses pembaikan tisu semulajadi.'
        ],
        normalSensations: 'Rasa sedikit sengal, kemerahan ringan atau denyutan lembut di kawasan rawatan adalah normal dan akan reda dalam 24-48 jam.',
        warningSigns: 'Kesakitan melampau yang berterusan, bengkak luar biasa atau lebam teruk. Sila hubungi doktor kami serta-merta sekiranya berlaku.',
        followUpRecommendation: 'Sesi rawatan seterusnya disyorkan dalam tempoh 5–7 hari mengikut pelan rawatan doktor anda.'
      },
      trt: {
        id: 'trt',
        name: 'Terapi Penggantian Testosteron (TRT)',
        englishName: 'Testosterone Replacement Therapy (TRT)',
        immediateGuidelines: [
          'Kekalkan kebersihan di kawasan suntikan; elakkan menggosok atau mengurut kawasan berkenaan.',
          'Catatkan sebarang perubahan tenaga, mood atau kualiti tidur dalam diari harian anda.',
          'Jangan mengubah dos atau masa rawatan tanpa arahan doktor bertugas.'
        ],
        normalSensations: 'Rasa tegang atau sedikit lenguh di otot tempat suntikan selama 1-2 hari pertama.',
        warningSigns: 'Sesak nafas, degupan jantung luar biasa pantas, atau bengkak pada betis/kaki.',
        followUpRecommendation: 'Ujian darah profil hormon (Total/Free T & Hematokrit) wajib dilakukan pada minggu ke-12.'
      },
      pe_ed: {
        id: 'pe_ed',
        name: 'Pelan Pemulihan Prestasi Klinikal (ED/PE)',
        englishName: 'Clinical Vitality & Performance Roadmap',
        immediateGuidelines: [
          'Ambil sebarang ubat preskripsi mengikut jadual tepat seperti yang diarahkan oleh doktor.',
          'Lakukan senaman kegel / lantai pelvis mengikut teknik yang diajar semasa sesi konsultasi.',
          'Kurangkan pengambilan nikotin dan alkohol bagi memaksimumkan aliran darah vaskular.'
        ],
        normalSensations: 'Penyesuaian fisiologi beransur-ansur; kesan rawatan optimum dicapai secara bertahap dalam 4-8 minggu.',
        warningSigns: 'Pening berpanjangan atau sakit dada selepas mengambil ubat vasoaktif.',
        followUpRecommendation: 'Sesi penilaian kemajuan klinikal dalam tempoh 14 hari.'
      },
      // kegel / pshot / fertility: added Oct 2026 to match the clinics' current offering.
      // Aftercare wording is conservative and general: Medical Director must review before clinical use.
      kegel: {
        id: 'kegel',
        name: 'Sesi Kerusi Kegel',
        englishName: 'Kegel Chair Session',
        immediateGuidelines: [
          'Minum air secukupnya dan teruskan aktiviti harian seperti biasa selepas sesi.',
          'Praktikkan teknik pengecutan otot lantai pelvis yang diajar jurulatih/doktor setiap hari.',
          'Hadiri sesi mengikut jadual kerana kesan latihan otot dibina secara berperingkat.'
        ],
        normalSensations: 'Rasa penat ringan atau lenguh pada otot pelvis selepas sesi adalah normal dan reda dalam sehari dua.',
        warningSigns: 'Sakit tajam yang berterusan, kebas, atau kesukaran membuang air kecil. Sila hubungi klinik.',
        followUpRecommendation: 'Sesi seterusnya mengikut pakej dan jadual yang ditetapkan doktor anda.'
      },
      pshot: {
        id: 'pshot',
        name: 'Rawatan Regeneratif (P-Shot)',
        englishName: 'Regenerative P-Shot Treatment',
        immediateGuidelines: [
          'Jaga kebersihan kawasan rawatan dan elakkan menggosok atau mengurut kawasan tersebut.',
          'Elakkan aktiviti berat dan hubungan intim mengikut tempoh yang dinasihatkan doktor.',
          'Ambil ubat yang dibekalkan (jika ada) mengikut arahan dan jangan ubah dos sendiri.'
        ],
        normalSensations: 'Bengkak ringan, kemerahan atau rasa sengal di kawasan rawatan pada 1-3 hari pertama.',
        warningSigns: 'Demam, nanah, bengkak yang bertambah teruk, kesakitan melampau atau pendarahan yang tidak berhenti. Sila hubungi klinik serta-merta.',
        followUpRecommendation: 'Semakan susulan bersama doktor mengikut tarikh yang diberikan.'
      },
      fertility: {
        id: 'fertility',
        name: 'Program Kesuburan Lelaki',
        englishName: 'Male Fertility Program',
        immediateGuidelines: [
          'Ikut arahan penyediaan sampel dan jadual sesi infusi yang diberikan klinik.',
          'Kurangkan merokok dan alkohol serta jaga tidur dan pemakanan sepanjang program.',
          'Maklumkan doktor jika sedang mengambil ubat atau suplemen lain.'
        ],
        normalSensations: 'Rasa mengantuk ringan atau sedikit lenguh selepas sesi infusi pada hari yang sama.',
        warningSigns: 'Ruam, sesak nafas, bengkak muka atau pening melampau semasa/selepas infusi. Sila maklumkan klinik serta-merta.',
        followUpRecommendation: 'Program 12 minggu dipantau berkala; analisis sperma susulan mengikut jadual doktor.'
      },
      minor_procedure: {
        id: 'minor_procedure',
        name: 'Penjagaan Prosedur Minor / Sirkumsisi',
        englishName: 'Minor Clinical Procedure & Dressing Care',
        immediateGuidelines: [
          'Pastikan balutan luka sentiasa kering dan bersih untuk 48 jam pertama.',
          'Pakai pakaian longgar yang selesa bagi mengurangkan geseran fizikal.',
          'Makan ubat antibiotik dan analgesik yang dibekalkan mengikut jadual.'
        ],
        normalSensations: 'Sedikit lelehan cecair jernih/merah muda pada balutan pada hari pertama.',
        warningSigns: 'Pendarahan aktif yang tidak berhenti, demam panas melebihi 38°C, atau nanah berbau.',
        followUpRecommendation: 'Temujanji pembukaan balutan dan semakan luka di klinik dalam tempoh 3-5 hari.'
      }
    };
  }

  getProtocols() {
    return Object.values(this.protocols);
  }

  getProtocol(id) {
    if (!id) return null;
    return this.protocols[id.toLowerCase()] || null;
  }

  generateDispatchMessage(options) {
    const {
      patientName = 'Pesakit',
      patientPhone = '',
      protocolId = 'eswt',
      branchCode = 'SSC-BSR',
      followUpDate = '',
      doctorName = ''
    } = options;

    const protocol = this.getProtocol(protocolId) || this.protocols.eswt;
    const branch = BranchService.getBranchByCode(branchCode) || BranchService.getBranches()[0];
    const doctor = doctorName || (branch.doctors && branch.doctors[0]) || "";

    const lines = [];
    lines.push(`🏥 *SUAMISIHAT CLINIC — PANDUAN PENJAGAAN DIGITAL*`);
    lines.push(`Salam sejahtera Tuan *${patientName}*,`);
    lines.push(`Terima kasih kerana memilih ${branch.shortName} untuk rawatan *${protocol.name}*.`);
    lines.push(``);
    lines.push(`📋 *PANDUAN PEMULIHAN 24-48 JAM PERTAMA:*`);
    protocol.immediateGuidelines.forEach((g, idx) => {
      lines.push(`  ${idx + 1}. ${g}`);
    });
    lines.push(``);
    lines.push(`ℹ️ *Sensasi Biasa:* ${protocol.normalSensations}`);
    lines.push(``);
    lines.push(`⚠️ *Tanda Amaran (Perlu Hubungi Klinik):* ${protocol.warningSigns}`);
    lines.push(``);
    if (followUpDate) {
      lines.push(`📅 *Temujanji Susulan Anda:* ${followUpDate}`);
    } else {
      lines.push(`📅 *Saranan Susulan:* ${protocol.followUpRecommendation}`);
    }
    lines.push(``);
    lines.push(`👨‍⚕️ *Doktor Bertugas:* ${doctor}`);
    lines.push(`📞 *Talian Kecemasan/Pertanyaan:* ${branch.phone} / WhatsApp: ${branch.whatsapp}`);
    lines.push(`📍 *Lokasi Klinik:* ${branch.address}`);
    lines.push(``);
    lines.push(`_Kekal sihat dan bertenaga bersama SuamiSihat._`);

    const formattedText = lines.join('\n');
    const cleanPhone = (patientPhone || '').replace(/[^0-9]/g, '');
    const encodedText = encodeURIComponent(formattedText);
    const whatsappUrl = cleanPhone ? `https://wa.me/${cleanPhone}?text=${encodedText}` : `https://wa.me/?text=${encodedText}`;

    return {
      patientName,
      patientPhone: cleanPhone,
      protocol: protocol.name,
      branch: branch.name,
      doctor,
      followUpDate,
      messageText: formattedText,
      whatsappUrl
    };
  }
}

module.exports = new CareDispatcherService();
