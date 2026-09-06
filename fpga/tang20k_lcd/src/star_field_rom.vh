// star_field_rom.vh -- 360deg Earth-style night sky (constellation figures)
// Map width STAR_MAP_W=3200 (4 * 800). Visible window is 800px = 90deg.
// Include from sw_scanout.v only. Do NOT add to Gowin FileList.
// Stick-figure constellations + irregular field stars. ASCII only.

`ifndef STAR_FIELD_ROM_VH
`define STAR_FIELD_ROM_VH

// Hit if (map_x, map_y) is a catalog star. map_x is 0..3199. my is 0..511.
function star_map_hit;
    input [11:0] mx;
    input [8:0]  my;
    begin
        case ({my, mx})
            // === band 0 (az 0..90deg): Ursa Major / Big Dipper ===
            // bowl
            {9'd78,  12'd110}:  star_map_hit = 1'b1;
            {9'd68,  12'd155}:  star_map_hit = 1'b1;
            {9'd72,  12'd200}:  star_map_hit = 1'b1;
            {9'd95,  12'd235}:  star_map_hit = 1'b1;
            // handle
            {9'd112, 12'd280}:  star_map_hit = 1'b1;
            {9'd138, 12'd330}:  star_map_hit = 1'b1;
            {9'd155, 12'd385}:  star_map_hit = 1'b1;
            // pointer helpers / field near dipper
            {9'd55,  12'd90}:   star_map_hit = 1'b1;
            {9'd130, 12'd170}:  star_map_hit = 1'b1;
            {9'd180, 12'd250}:  star_map_hit = 1'b1;
            // Cassiopeia (W)
            {9'd52,  12'd520}:  star_map_hit = 1'b1;
            {9'd88,  12'd555}:  star_map_hit = 1'b1;
            {9'd48,  12'd590}:  star_map_hit = 1'b1;
            {9'd92,  12'd625}:  star_map_hit = 1'b1;
            {9'd45,  12'd660}:  star_map_hit = 1'b1;
            // Cepheus house (near Cass)
            {9'd120, 12'd700}:  star_map_hit = 1'b1;
            {9'd150, 12'd730}:  star_map_hit = 1'b1;
            {9'd150, 12'd770}:  star_map_hit = 1'b1;
            {9'd185, 12'd715}:  star_map_hit = 1'b1;
            {9'd185, 12'd755}:  star_map_hit = 1'b1;
            // field
            {9'd220, 12'd40}:   star_map_hit = 1'b1;
            {9'd300, 12'd320}:  star_map_hit = 1'b1;
            {9'd350, 12'd480}:  star_map_hit = 1'b1;
            {9'd400, 12'd150}:  star_map_hit = 1'b1;
            {9'd420, 12'd610}:  star_map_hit = 1'b1;
            {9'd280, 12'd750}:  star_map_hit = 1'b1;
            {9'd360, 12'd70}:   star_map_hit = 1'b1;
            {9'd440, 12'd400}:  star_map_hit = 1'b1;

            // === band 1 (az 90..180deg): Orion + Taurus ===
            // Orion shoulders
            {9'd155, 12'd960}:  star_map_hit = 1'b1;  // Bellatrix
            {9'd148, 12'd1100}: star_map_hit = 1'b1;  // Betelgeuse
            // belt
            {9'd220, 12'd1000}: star_map_hit = 1'b1;
            {9'd225, 12'd1040}: star_map_hit = 1'b1;
            {9'd230, 12'd1080}: star_map_hit = 1'b1;
            // sword
            {9'd250, 12'd1040}: star_map_hit = 1'b1;
            {9'd270, 12'd1045}: star_map_hit = 1'b1;
            {9'd290, 12'd1040}: star_map_hit = 1'b1;
            // feet
            {9'd310, 12'd980}:  star_map_hit = 1'b1;  // Rigel side
            {9'd318, 12'd1110}: star_map_hit = 1'b1;
            // head
            {9'd175, 12'd1035}: star_map_hit = 1'b1;
            // Taurus V (Hyades) + Aldebaran
            {9'd200, 12'd820}:  star_map_hit = 1'b1;
            {9'd210, 12'd850}:  star_map_hit = 1'b1;
            {9'd230, 12'd870}:  star_map_hit = 1'b1;
            {9'd210, 12'd890}:  star_map_hit = 1'b1;
            {9'd190, 12'd875}:  star_map_hit = 1'b1;  // Aldebaran
            // Pleiades clump
            {9'd120, 12'd780}:  star_map_hit = 1'b1;
            {9'd115, 12'd790}:  star_map_hit = 1'b1;
            {9'd125, 12'd800}:  star_map_hit = 1'b1;
            {9'd118, 12'd808}:  star_map_hit = 1'b1;
            {9'd128, 12'd795}:  star_map_hit = 1'b1;
            {9'd122, 12'd815}:  star_map_hit = 1'b1;
            // Canis Major (Sirius)
            {9'd340, 12'd1200}: star_map_hit = 1'b1;
            {9'd360, 12'd1230}: star_map_hit = 1'b1;
            {9'd355, 12'd1260}: star_map_hit = 1'b1;
            {9'd380, 12'd1245}: star_map_hit = 1'b1;
            // Gemini twins
            {9'd100, 12'd1350}: star_map_hit = 1'b1;
            {9'd105, 12'd1420}: star_map_hit = 1'b1;
            {9'd160, 12'd1360}: star_map_hit = 1'b1;
            {9'd165, 12'd1410}: star_map_hit = 1'b1;
            {9'd220, 12'd1370}: star_map_hit = 1'b1;
            {9'd225, 12'd1400}: star_map_hit = 1'b1;
            // field
            {9'd60,  12'd930}:  star_map_hit = 1'b1;
            {9'd400, 12'd1050}: star_map_hit = 1'b1;
            {9'd450, 12'd1300}: star_map_hit = 1'b1;
            {9'd80,  12'd1500}: star_map_hit = 1'b1;
            {9'd300, 12'd1550}: star_map_hit = 1'b1;

            // === band 2 (az 180..270deg): Cygnus + Lyra + Aquila ===
            // Cygnus Northern Cross
            {9'd70,  12'd1740}: star_map_hit = 1'b1;  // Deneb
            {9'd130, 12'd1740}: star_map_hit = 1'b1;
            {9'd190, 12'd1740}: star_map_hit = 1'b1;
            {9'd250, 12'd1740}: star_map_hit = 1'b1;  // Albireo end
            {9'd130, 12'd1680}: star_map_hit = 1'b1;  // wing
            {9'd130, 12'd1800}: star_map_hit = 1'b1;  // wing
            // Lyra (Vega)
            {9'd90,  12'd1620}: star_map_hit = 1'b1;
            {9'd110, 12'd1640}: star_map_hit = 1'b1;
            {9'd110, 12'd1600}: star_map_hit = 1'b1;
            {9'd130, 12'd1630}: star_map_hit = 1'b1;
            // Aquila (Altair)
            {9'd260, 12'd1880}: star_map_hit = 1'b1;
            {9'd280, 12'd1860}: star_map_hit = 1'b1;
            {9'd280, 12'd1900}: star_map_hit = 1'b1;
            {9'd300, 12'd1880}: star_map_hit = 1'b1;
            {9'd320, 12'd1870}: star_map_hit = 1'b1;
            // Scorpius curve
            {9'd300, 12'd2050}: star_map_hit = 1'b1;  // Antares
            {9'd280, 12'd2090}: star_map_hit = 1'b1;
            {9'd270, 12'd2130}: star_map_hit = 1'b1;
            {9'd290, 12'd2170}: star_map_hit = 1'b1;
            {9'd320, 12'd2200}: star_map_hit = 1'b1;
            {9'd360, 12'd2220}: star_map_hit = 1'b1;
            {9'd400, 12'd2210}: star_map_hit = 1'b1;
            {9'd430, 12'd2180}: star_map_hit = 1'b1;
            {9'd450, 12'd2140}: star_map_hit = 1'b1;
            // stinger
            {9'd460, 12'd2100}: star_map_hit = 1'b1;
            {9'd455, 12'd2060}: star_map_hit = 1'b1;
            // Sagittarius teapot
            {9'd340, 12'd2280}: star_map_hit = 1'b1;
            {9'd360, 12'd2310}: star_map_hit = 1'b1;
            {9'd360, 12'd2350}: star_map_hit = 1'b1;
            {9'd340, 12'd2380}: star_map_hit = 1'b1;
            {9'd320, 12'd2350}: star_map_hit = 1'b1;
            {9'd320, 12'd2310}: star_map_hit = 1'b1;
            {9'd300, 12'd2290}: star_map_hit = 1'b1;  // spout
            // field
            {9'd50,  12'd1950}: star_map_hit = 1'b1;
            {9'd180, 12'd2100}: star_map_hit = 1'b1;
            {9'd420, 12'd1700}: star_map_hit = 1'b1;
            {9'd200, 12'd2360}: star_map_hit = 1'b1;

            // === band 3 (az 270..360deg): Leo + Southern Cross + Crux ===
            // Leo sickle (backwards question mark)
            {9'd100, 12'd2480}: star_map_hit = 1'b1;  // Regulus base area
            {9'd80,  12'd2510}: star_map_hit = 1'b1;
            {9'd60,  12'd2540}: star_map_hit = 1'b1;
            {9'd55,  12'd2580}: star_map_hit = 1'b1;
            {9'd70,  12'd2610}: star_map_hit = 1'b1;
            {9'd100, 12'd2620}: star_map_hit = 1'b1;
            {9'd140, 12'd2500}: star_map_hit = 1'b1;  // body
            {9'd160, 12'd2550}: star_map_hit = 1'b1;
            {9'd170, 12'd2600}: star_map_hit = 1'b1;
            // Southern Cross (Crux)
            {9'd280, 12'd2800}: star_map_hit = 1'b1;
            {9'd320, 12'd2800}: star_map_hit = 1'b1;
            {9'd360, 12'd2800}: star_map_hit = 1'b1;
            {9'd320, 12'd2760}: star_map_hit = 1'b1;
            {9'd320, 12'd2840}: star_map_hit = 1'b1;
            // Pointers (to cross)
            {9'd300, 12'd2680}: star_map_hit = 1'b1;
            {9'd340, 12'd2720}: star_map_hit = 1'b1;
            // Summer triangle remnant / field bright
            {9'd90,  12'd2900}: star_map_hit = 1'b1;
            {9'd200, 12'd3000}: star_map_hit = 1'b1;
            {9'd320, 12'd3100}: star_map_hit = 1'b1;
            // Andromeda chain into band wrap
            {9'd150, 12'd3050}: star_map_hit = 1'b1;
            {9'd170, 12'd3100}: star_map_hit = 1'b1;
            {9'd190, 12'd3150}: star_map_hit = 1'b1;
            {9'd210, 12'd3180}: star_map_hit = 1'b1;
            // field
            {9'd400, 12'd2450}: star_map_hit = 1'b1;
            {9'd440, 12'd2650}: star_map_hit = 1'b1;
            {9'd50,  12'd2750}: star_map_hit = 1'b1;
            {9'd420, 12'd2950}: star_map_hit = 1'b1;
            {9'd250, 12'd3120}: star_map_hit = 1'b1;
            {9'd380, 12'd3180}: star_map_hit = 1'b1;

            default: star_map_hit = 1'b0;
        endcase
    end
endfunction

`endif
