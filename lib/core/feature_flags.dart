/// Liga/desliga partes do app sem apagar o codigo.
///
/// Ilha Top: DESLIGADA (out/2026) para economizar trafego no Supabase. Com
/// false, o menu some e nada da Ilha (avatares, fundos, videos) e baixado.
/// O codigo e os dados continuam intactos: para religar, mude para true e
/// gere uma nova versao do app.
const kIlhaTopEnabled = false;
