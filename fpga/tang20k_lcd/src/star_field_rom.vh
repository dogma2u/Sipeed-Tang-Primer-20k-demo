// star_field_rom.vh -- 360deg night sky, exactly 60 catalog stars (LUT budget)
// Map width STAR_MAP_W=3200 (4 * 800). Visible window is 800px = 90deg.
// Include from sw_scanout.v only. Do NOT add to Gowin FileList.
// Constellation skeletons only. ASCII only.

`ifndef STAR_FIELD_ROM_VH
`define STAR_FIELD_ROM_VH

// Hit if (map_x, map_y) is a catalog star. map_x is 0..3199. my is 0..511.
function star_map_hit;
    input [11:0] mx;
    input [8:0]  my;
    begin
        case ({my, mx})
            // Big Dipper 7
            {9'd78,  12'd110}:  star_map_hit = 1'b1;
            {9'd68,  12'd155}:  star_map_hit = 1'b1;
            {9'd72,  12'd200}:  star_map_hit = 1'b1;
            {9'd95,  12'd235}:  star_map_hit = 1'b1;
            {9'd112, 12'd280}:  star_map_hit = 1'b1;
            {9'd138, 12'd330}:  star_map_hit = 1'b1;
            {9'd155, 12'd385}:  star_map_hit = 1'b1;
            // Cassiopeia 5
            {9'd52,  12'd520}:  star_map_hit = 1'b1;
            {9'd88,  12'd555}:  star_map_hit = 1'b1;
            {9'd48,  12'd590}:  star_map_hit = 1'b1;
            {9'd92,  12'd625}:  star_map_hit = 1'b1;
            {9'd45,  12'd660}:  star_map_hit = 1'b1;
            // Cepheus 3
            {9'd120, 12'd700}:  star_map_hit = 1'b1;
            {9'd150, 12'd730}:  star_map_hit = 1'b1;
            {9'd185, 12'd755}:  star_map_hit = 1'b1;

            // Orion 8
            {9'd155, 12'd960}:  star_map_hit = 1'b1;
            {9'd148, 12'd1100}: star_map_hit = 1'b1;
            {9'd220, 12'd1000}: star_map_hit = 1'b1;
            {9'd225, 12'd1040}: star_map_hit = 1'b1;
            {9'd230, 12'd1080}: star_map_hit = 1'b1;
            {9'd270, 12'd1045}: star_map_hit = 1'b1;
            {9'd310, 12'd980}:  star_map_hit = 1'b1;
            {9'd318, 12'd1110}: star_map_hit = 1'b1;
            // Taurus 3
            {9'd200, 12'd820}:  star_map_hit = 1'b1;
            {9'd230, 12'd870}:  star_map_hit = 1'b1;
            {9'd190, 12'd875}:  star_map_hit = 1'b1;
            // Pleiades 2
            {9'd120, 12'd780}:  star_map_hit = 1'b1;
            {9'd125, 12'd800}:  star_map_hit = 1'b1;
            // Sirius + Gemini 3
            {9'd340, 12'd1200}: star_map_hit = 1'b1;
            {9'd100, 12'd1350}: star_map_hit = 1'b1;
            {9'd105, 12'd1420}: star_map_hit = 1'b1;

            // Cygnus 5
            {9'd70,  12'd1740}: star_map_hit = 1'b1;
            {9'd130, 12'd1740}: star_map_hit = 1'b1;
            {9'd190, 12'd1740}: star_map_hit = 1'b1;
            {9'd250, 12'd1740}: star_map_hit = 1'b1;
            {9'd130, 12'd1800}: star_map_hit = 1'b1;
            // Vega + Altair 4
            {9'd90,  12'd1620}: star_map_hit = 1'b1;
            {9'd110, 12'd1640}: star_map_hit = 1'b1;
            {9'd260, 12'd1880}: star_map_hit = 1'b1;
            {9'd300, 12'd1880}: star_map_hit = 1'b1;
            // Scorpius 4
            {9'd300, 12'd2050}: star_map_hit = 1'b1;
            {9'd280, 12'd2090}: star_map_hit = 1'b1;
            {9'd320, 12'd2200}: star_map_hit = 1'b1;
            {9'd450, 12'd2140}: star_map_hit = 1'b1;
            // Teapot 4
            {9'd340, 12'd2280}: star_map_hit = 1'b1;
            {9'd360, 12'd2350}: star_map_hit = 1'b1;
            {9'd320, 12'd2310}: star_map_hit = 1'b1;
            {9'd300, 12'd2290}: star_map_hit = 1'b1;

            // Leo 4
            {9'd100, 12'd2480}: star_map_hit = 1'b1;
            {9'd80,  12'd2510}: star_map_hit = 1'b1;
            {9'd60,  12'd2540}: star_map_hit = 1'b1;
            {9'd160, 12'd2550}: star_map_hit = 1'b1;
            // Crux 5
            {9'd280, 12'd2800}: star_map_hit = 1'b1;
            {9'd320, 12'd2800}: star_map_hit = 1'b1;
            {9'd360, 12'd2800}: star_map_hit = 1'b1;
            {9'd320, 12'd2760}: star_map_hit = 1'b1;
            {9'd320, 12'd2840}: star_map_hit = 1'b1;
            // Andromeda 3  (7+5+3+8+3+2+3+5+4+4+4+4+5+3 = 60)
            {9'd150, 12'd3050}: star_map_hit = 1'b1;
            {9'd170, 12'd3100}: star_map_hit = 1'b1;
            {9'd210, 12'd3180}: star_map_hit = 1'b1;

            default: star_map_hit = 1'b0;
        endcase
    end
endfunction

`endif
