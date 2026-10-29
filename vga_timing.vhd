library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_timing is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        pixel_x      : out unsigned(9 downto 0);
        pixel_y      : out unsigned(9 downto 0);
        video_active : out std_logic;
        frame_tick   : out std_logic;
        hsync        : out std_logic;
        vsync        : out std_logic
    );
end entity vga_timing;

architecture rtl of vga_timing is
    signal pixel_ce : std_logic := '0';
    signal h_count  : integer range 0 to 799 := 0;
    signal v_count  : integer range 0 to 524 := 0;
begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pixel_ce <= '0';
                h_count  <= 0;
                v_count  <= 0;
            else
                pixel_ce <= not pixel_ce;

                if pixel_ce = '1' then
                    if h_count = 799 then
                        h_count <= 0;

                        if v_count = 524 then
                            v_count <= 0;
                        else
                            v_count <= v_count + 1;
                        end if;
                    else
                        h_count <= h_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    pixel_x <= to_unsigned(h_count, 10);
    pixel_y <= to_unsigned(v_count, 10);

    video_active <= '1' when h_count < 640 and v_count < 480
                    else '0';

    frame_tick <= '1' when pixel_ce = '1' and
                           h_count = 0 and v_count = 0
                  else '0';

    hsync <= '0' when h_count >= 656 and h_count < 752 else '1';
    vsync <= '0' when v_count >= 490 and v_count < 492 else '1';

end architecture rtl;
