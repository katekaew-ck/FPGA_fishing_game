library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity renderer is
    port (
        pixel_x, pixel_y : in unsigned(9 downto 0);
        video_active : in std_logic;
        state_code : in std_logic_vector(1 downto 0);
        hook_x, hook_y : in unsigned(9 downto 0);
        fish_x_bus, fish_y_bus : in std_logic_vector(49 downto 0);
        fish_kind_bus : in std_logic_vector(9 downto 0);
        fish_dir_bus, fish_visible : in std_logic_vector(4 downto 0);
        held_active : in std_logic;
        held_kind : in std_logic_vector(1 downto 0);
        boot_x, boot_y, eel_x, eel_y : in unsigned(9 downto 0);
        stunned : in std_logic;
        score : in unsigned(9 downto 0);
        remaining_seconds : in unsigned(6 downto 0);
        red_out, green_out, blue_out : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of renderer is
    function glyph(c : character) return std_logic_vector is
    begin
        case c is
            when 'A' => return "01110" & "10001" & "10001" &
                               "11111" & "10001" & "10001" & "10001";
            when 'C' => return "01111" & "10000" & "10000" &
                               "10000" & "10000" & "10000" & "01111";
            when 'D' => return "11110" & "10001" & "10001" &
                               "10001" & "10001" & "10001" & "11110";
            when 'E' => return "11111" & "10000" & "10000" &
                               "11110" & "10000" & "10000" & "11111";
            when 'F' => return "11111" & "10000" & "10000" &
                               "11110" & "10000" & "10000" & "10000";
            when 'G' => return "01111" & "10000" & "10000" &
                               "10111" & "10001" & "10001" & "01111";
            when 'H' => return "10001" & "10001" & "10001" &
                               "11111" & "10001" & "10001" & "10001";
            when 'I' => return "11111" & "00100" & "00100" &
                               "00100" & "00100" & "00100" & "11111";
            when 'L' => return "10000" & "10000" & "10000" &
                               "10000" & "10000" & "10000" & "11111";
            when 'M' => return "10001" & "11011" & "10101" &
                               "10101" & "10001" & "10001" & "10001";
            when 'N' => return "10001" & "11001" & "10101" &
                               "10011" & "10001" & "10001" & "10001";
            when 'O' => return "01110" & "10001" & "10001" &
                               "10001" & "10001" & "10001" & "01110";
            when 'P' => return "11110" & "10001" & "10001" &
                               "11110" & "10000" & "10000" & "10000";
            when 'R' => return "11110" & "10001" & "10001" &
                               "11110" & "10100" & "10010" & "10001";
            when 'S' => return "01111" & "10000" & "10000" &
                               "01110" & "00001" & "00001" & "11110";
            when 'T' => return "11111" & "00100" & "00100" &
                               "00100" & "00100" & "00100" & "00100";
            when 'U' => return "10001" & "10001" & "10001" &
                               "10001" & "10001" & "10001" & "01110";
            when 'V' => return "10001" & "10001" & "10001" &
                               "10001" & "10001" & "01010" & "00100";
            when 'Y' => return "10001" & "10001" & "01010" &
                               "00100" & "00100" & "00100" & "00100";
            when others => return (34 downto 0 => '0');
        end case;
    end function;

    function text_on(s : string; px,py,x0,y0 : integer;
                     scale : positive) return boolean is
        variable dx,dy : integer;
        variable pattern : std_logic_vector(34 downto 0);
    begin
        dy := py - y0;
        if dy < 0 or dy >= 7*scale then return false; end if;
        for i in s'range loop
            dx := px - (x0 + (i-s'low)*6*scale);
            if dx >= 0 and dx < 5*scale then
                pattern := glyph(s(i));
                if pattern(34 - (dy/scale)*5 - dx/scale) = '1' then
                    return true;
                end if;
            end if;
        end loop;
        return false;
    end function;

    function digit_on(px,py,x0,y0,n : integer) return boolean is
        variable x,y : integer;
        variable seg : std_logic_vector(6 downto 0);
    begin
        x:=px-x0; y:=py-y0;
        if x<0 or x>=18 or y<0 or y>=30 then return false; end if;
        case n is
            when 0 => seg:="1111110";
            when 1 => seg:="0110000";
            when 2 => seg:="1101101";
            when 3 => seg:="1111001";
            when 4 => seg:="0110011";
            when 5 => seg:="1011011";
            when 6 => seg:="1011111";
            when 7 => seg:="1110000";
            when 8 => seg:="1111111";
            when 9 => seg:="1111011";
            when others => seg:="0000000";
        end case;
        return
            (seg(6)='1' and y<=2 and x>=2 and x<=15) or
            (seg(5)='1' and x>=15 and y>=2 and y<=14) or
            (seg(4)='1' and x>=15 and y>=15 and y<=27) or
            (seg(3)='1' and y>=27 and x>=2 and x<=15) or
            (seg(2)='1' and x<=2 and y>=15 and y<=27) or
            (seg(1)='1' and x<=2 and y>=2 and y<=14) or
            (seg(0)='1' and y>=14 and y<=16 and x>=2 and x<=15);
    end function;

    function coral_on(px,py,cx : integer) return boolean is
        variable dx : integer;
    begin
        dx:=px-cx;
        return
            (abs(dx)<=3 and py>=412 and py<=458) or
            (dx>=-19 and dx<=-2 and py>=433 and py<=439) or
            (dx>=-19 and dx<=-13 and py>=423 and py<=439) or
            (dx>=3 and dx<=21 and py>=439 and py<=446) or
            (dx>=16 and dx<=23 and py>=426 and py<=446);
    end function;

    function seaweed_on(px,py,cx : integer) return boolean is
        variable dx,h : integer;
    begin
        dx:=px-cx; h:=458-py;
        if h<0 or h>63 then return false; end if;
        return
            (h<20 and dx>=-2 and dx<=1) or
            (h>=20 and h<36 and dx>=1 and dx<=4) or
            (h>=36 and h<52 and dx>=-2 and dx<=1) or
            (h>=52 and dx>=2 and dx<=5) or
            (h>=12 and h<=16 and dx>=-12 and dx<=-2) or
            (h>=28 and h<=32 and dx>=4 and dx<=13) or
            (h>=44 and h<=48 and dx>=-11 and dx<=-2);
    end function;

    procedure paint_fish(
        constant px,py,fx,fy : in integer;
        constant kind : in std_logic_vector(1 downto 0);
        constant dir_right : in std_logic;
        variable rr,gg,bb : inout std_logic_vector(3 downto 0)
    ) is
        variable dx,dy : integer;
        variable fish_body,fish_tail : boolean;
    begin
        dx:=px-fx; dy:=py-fy;
        if dir_right='0' then dx:=27-dx; end if;
        fish_body := dx>=6 and dx<=26 and dy>=2 and dy<=13 and
                not ((dx<9 or dx>23) and (dy<5 or dy>10));
        fish_tail := dx>=0 and dx<=8 and dy>=0 and dy<=15 and
                abs(dy-8) <= (8-dx)/2;
        if fish_body or fish_tail then
            case kind is
                when "00" => rr:=x"F"; gg:=x"C"; bb:=x"2";
                when "01" => rr:=x"1"; gg:=x"D"; bb:=x"F";
                when "10" => rr:=x"F"; gg:=x"3"; bb:=x"9";
                when others =>
                    if dx<=4 then rr:=x"F";gg:=x"2";bb:=x"2";
                    elsif dx<=9 then rr:=x"F";gg:=x"8";bb:=x"0";
                    elsif dx<=14 then rr:=x"F";gg:=x"F";bb:=x"0";
                    elsif dx<=19 then rr:=x"2";gg:=x"F";bb:=x"3";
                    elsif dx<=23 then rr:=x"2";gg:=x"7";bb:=x"F";
                    else rr:=x"C";gg:=x"3";bb:=x"F";
                    end if;
            end case;
            if fish_body and kind/="11" and dy=8 and dx>=10 and dx<=19 then
                rr:=x"F";gg:=x"F";bb:=x"F";
            end if;
            if fish_body and dx>=22 and dx<=23 and dy>=5 and dy<=6 then
                rr:=x"0";gg:=x"0";bb:=x"1";
            end if;
        end if;
    end procedure;
begin
    process(pixel_x,pixel_y,video_active,state_code,hook_x,hook_y,
            fish_x_bus,fish_y_bus,fish_kind_bus,fish_dir_bus,fish_visible,
            held_active,held_kind,boot_x,boot_y,eel_x,eel_y,stunned,
            score,remaining_seconds)
        variable px,py,hx,hy,fx,fy,dx,dy : integer;
        variable score_value,time_value : integer;
        variable rr,gg,bb : std_logic_vector(3 downto 0);
        variable fish_found : boolean;
        variable selected_kind : std_logic_vector(1 downto 0);
        variable selected_dir : std_logic;
    begin
        rr:=x"0";gg:=x"0";bb:=x"0";
        px:=to_integer(pixel_x); py:=to_integer(pixel_y);
        hx:=to_integer(hook_x); hy:=to_integer(hook_y);
        score_value:=to_integer(score);
        time_value:=to_integer(remaining_seconds);

        if video_active='1' then
            if state_code="10" then
                rr:=x"2";gg:=x"0";bb:=x"3";
                if text_on("GAME OVER",px,py,155,175,6) then
                    rr:=x"F";gg:=x"F";bb:=x"F";
                end if;
                if text_on("LEFT RESTART",px,py,230,295,2) or
                   text_on("RIGHT READY",px,py,230,328,2) then
                    rr:=x"F";gg:=x"C";bb:=x"5";
                end if;
            else

                if py<80 then rr:=x"2";gg:=x"7";bb:=x"C";
                elsif py<230 then rr:=x"0";gg:=x"5";bb:=x"A";
                elsif py<400 then rr:=x"0";gg:=x"3";bb:=x"8";
                else rr:=x"0";gg:=x"2";bb:=x"5";
                end if;
                if py>=79 and py<=81 then rr:=x"9";gg:=x"E";bb:=x"F";end if;
                if py>=456 then rr:=x"7";gg:=x"8";bb:=x"6";end if;

                if coral_on(px,py,90) then
                    rr:=x"F";gg:=x"6";bb:=x"5";
                elsif coral_on(px,py,535) then
                    rr:=x"C";gg:=x"5";bb:=x"C";
                end if;
                if seaweed_on(px,py,190) or seaweed_on(px,py,280) or
                   seaweed_on(px,py,430) then
                    rr:=x"1";gg:=x"B";bb:=x"5";
                end if;

                if (abs(px-155)<=2 and py>=445 and py<=469) or
                   (abs(py-455)<=2 and px>=143 and px<=167) or
                   (abs(px-155)+abs(py-455)<=9 and
                    abs(px-155)>=3 and abs(py-455)>=3) then
                    rr:=x"F";gg:=x"9";bb:=x"4";
                end if;

                if (abs(px-360)+abs(py-335)=5) or
                   (abs(px-372)+abs(py-309)=4) or
                   (abs(px-65)+abs(py-260)=4) then
                    rr:=x"8";gg:=x"E";bb:=x"F";
                end if;

                dx:=px-hx;
                if py>=60 and py<=72 and dx>=-32 and dx<=32 then
                    rr:=x"9";gg:=x"5";bb:=x"2";
                end if;
                if py>=73 and py<=79 and abs(dx)<=32-(py-72)*3 then
                    rr:=x"7";gg:=x"3";bb:=x"1";
                end if;
                if py>=34 and py<=43 and dx>=-13 and dx<=-5 then
                    rr:=x"F";gg:=x"C";bb:=x"8";
                end if;
                if py>=44 and py<=59 and dx>=-13 and dx<=-6 then
                    rr:=x"3";gg:=x"7";bb:=x"B";
                end if;
                if py>=49 and py<=52 and dx>=-5 and dx<=12 then
                    rr:=x"F";gg:=x"C";bb:=x"8";
                end if;
                if py>=39 and py<=41 and dx>=-16 and dx<=-2 then
                    rr:=x"4";gg:=x"2";bb:=x"1";
                end if;
                if py>=48 and py<=50 and dx>=9 and dx<=29 then
                    rr:=x"D";gg:=x"D";bb:=x"D";
                end if;

                if state_code="00" then
                    if text_on("READY",px,py,230,180,6) then
                        rr:=x"F";gg:=x"E";bb:=x"3";
                    end if;
                    if text_on("PRESS TO START",px,py,194,270,3) then
                        rr:=x"F";gg:=x"F";bb:=x"F";
                    end if;
                else

                    fish_found:=false;
                    fx:=0; fy:=0;
                    selected_kind:="00";
                    selected_dir:='1';
                    for i in 0 to 4 loop
                        if fish_visible(i)='1' and
                           py>=to_integer(unsigned(fish_y_bus(i*10+9 downto i*10))) and
                           py<to_integer(unsigned(fish_y_bus(i*10+9 downto i*10)))+16 then
                            fx:=to_integer(unsigned(fish_x_bus(i*10+9 downto i*10)));
                            fy:=to_integer(unsigned(fish_y_bus(i*10+9 downto i*10)));
                            selected_kind:=fish_kind_bus(i*2+1 downto i*2);
                            selected_dir:=fish_dir_bus(i);
                            fish_found:=true;
                        end if;
                    end loop;
                    if fish_found then
                        paint_fish(px,py,fx,fy,selected_kind,selected_dir,rr,gg,bb);
                    end if;
                    if held_active='1' then
                        paint_fish(px,py,hx-14,hy+6,held_kind,'1',rr,gg,bb);
                    end if;

                    dx:=px-to_integer(boot_x);
                    dy:=py-to_integer(boot_y);
                    if (dx>=5 and dx<=20 and dy>=2 and dy<=15) or
                       (dx>=5 and dx<=25 and dy>=15 and dy<=19) then
                        rr:=x"A";gg:=x"5";bb:=x"1";
                        if dy>=18 then rr:=x"3";gg:=x"2";bb:=x"1";end if;
                        if dy>=2 and dy<=4 and dx>=2 and dx<=22 then
                            rr:=x"D";gg:=x"9";bb:=x"3";
                        end if;
                    end if;

                    dx:=px-to_integer(eel_x);
                    dy:=py-to_integer(eel_y);
                    if (dx>=1 and dx<=35 and dy>=0 and dy<=15) then
                        if (dx<=9 and dy>=6 and dy<=10) or
                           (dx>=10 and dx<=18 and dy>=3 and dy<=8) or
                           (dx>=19 and dx<=27 and dy>=7 and dy<=12) or
                           (dx>=28 and dy>=4 and dy<=9) then
                            rr:=x"F";gg:=x"E";bb:=x"2";
                            if dx>=29 and dx<=30 and dy=6 then
                                rr:=x"0";gg:=x"1";bb:=x"3";
                            end if;
                        end if;
                    end if;

                    if px>=hx-1 and px<=hx+1 and py>=78 and py<hy then
                        rr:=x"D";gg:=x"E";bb:=x"F";
                    end if;
                    if px>=hx-4 and px<=hx+4 and
                       py>=hy-4 and py<=hy+4 then
                        rr:=x"F";gg:=x"3";bb:=x"3";
                    end if;
                    if stunned='1' and
                       text_on("STUN",px,py,292,95,2) then
                        rr:=x"F";gg:=x"F";bb:=x"1";
                    end if;
                end if;
            end if;

            if text_on("SCORE",px,py,10,14,2) or
               text_on("TIME",px,py,445,14,2) or
               digit_on(px,py,95,8,score_value/100) or
               digit_on(px,py,116,8,(score_value/10) mod 10) or
               digit_on(px,py,137,8,score_value mod 10) or
               digit_on(px,py,545,8,time_value/10) or
               digit_on(px,py,566,8,time_value mod 10) then
                rr:=x"F";gg:=x"F";bb:=x"F";
            end if;
        end if;
        red_out<=rr; green_out<=gg; blue_out<=bb;
    end process;
end architecture;
