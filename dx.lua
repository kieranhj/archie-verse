file1 = io.open("src/scale_plot_generated.asm", "w")

source_width=216
min_width=64
max_width=216
width_step=2

file1:write(string.format("; R12=screen addr\n"))
file1:write(string.format("; R11=src ptr\n"))
file1:write(string.format("; R10=colour word\n"))
file1:write(string.format("; R9 =temp\n"))
file1:write(string.format("; R8 =accumulated word\n"))

for width=min_width,max_width,width_step do

    -- step in src_x
    dx = source_width / width


    src_x = 0.5
    src_word = 0

    dst_x = (source_width-width)/2
    dst_left = dst_x
    dst_word = dst_x // 8
    dst_pixel = dst_x % 8

    file1:write(string.format("; width=%d dx=%f left=%d right=%d\n", width, dx, dst_left, dst_left+width))
    file1:write(string.format("plot_width_%d:\n", width))
    file1:write(string.format("add r12, r12, #%d\t; dst word=%d dst pixel=%d\n",dst_word*4,dst_word,dst_pixel))

    -- first dst word may start midway through.
    cur_x = src_x
    if dst_pixel > 0 then

        src_x_end = src_x + (7-dst_pixel)*dx
        src_word_end = src_x_end // 8

        file1:write(string.format("; plot initial word at offet %d with dst pixels [%d, %d] from src pixels [%d, %d]\n",dst_pixel,dst_x-dst_left, dst_x-dst_left+7-dst_pixel, math.modf(src_x), math.modf(src_x_end)))

        -- we have enough here to write out the code for the initial word.
        if src_word==src_word_end then
            file1:write(string.format("ldr r%d, [r11], #4\t\t; src words [%d, %d]\n", src_word_end-src_word,src_word,src_word_end))
        else
            file1:write(string.format("ldmia r11!, {r%d-r%d}\t; src words [%d, %d]\n", 0, src_word_end-src_word,src_word,src_word_end))
        end
        file1:write(string.format("mov r8, #0\n"))

        cur_x = src_x
        dst_pixel = dst_x % 8
        while dst_pixel < 8 do
            cur_word = cur_x // 8
            cur_reg = cur_word - src_word
            cur_offset = math.modf(cur_x) % 8
            file1:write(string.format("and r9, r%d, #0x%x\n", cur_reg, 0xf << (cur_offset)*4))
            shift = (dst_pixel*4) - (cur_offset*4)
            if shift < 0 then
                file1:write(string.format("orr r8, r8, r9, lsr #%d\t; mask src pixel %d to dst pixel %d\n", -shift, math.modf(cur_x), dst_pixel))
            else
                file1:write(string.format("orr r8, r8, r9, lsl #%d\t; mask src pixel %d to dst pixel %d\n", shift, math.modf(cur_x), dst_pixel))
            end

            cur_x = cur_x + dx
            dst_pixel = dst_pixel + 1
            dst_x = dst_x + 1
        end

        file1:write(string.format("str r8, [r12], #4\n"))
    end

    -- loop for middle dst words
    dst_x_end = dst_left + width
    dst_x_end_middle=(dst_x_end // 8) * 8
    for dst_word=dst_x,dst_x_end_middle-1,8 do
        src_x = cur_x
        src_word = src_x // 8

        if src_word == src_word_end then
            -- We need to reuse final source word from last dst word.
            if cur_reg == 0 then
                file1:write(string.format("\t\t\t; reuse src word %d in R0\n", src_word))
            else
                file1:write(string.format("mov r0, r%d\t\t; reuse src word %d\n", cur_reg, src_word))
            end
            src_word_start=src_word+1
        else
            src_word_start=src_word
        end

        src_x_end = src_x + 7*dx
        src_word_end = src_x_end // 8

        file1:write(string.format("; plot dst pixels [%d, %d] from src pixels [%d, %d]\n",dst_x-dst_left, dst_x-dst_left+7, math.modf(src_x), math.modf(src_x_end)))

        if src_word_start==src_word_end then
            file1:write(string.format("ldr r%d, [r11], #4\t\t; src words [%d, %d]\n", src_word_start-src_word, src_word_end-src_word,src_word_start,src_word_end))
        else
            if src_word_start < src_word_end then
                file1:write(string.format("ldmia r11!, {r%d-r%d}\t; src words [%d, %d]\n", src_word_start-src_word, src_word_end-src_word,src_word_start,src_word_end))
            end
        end

        file1:write(string.format("mov r8, #0\n"))
        for dst_pixel=0,7 do
            cur_word = cur_x // 8
            cur_reg = cur_word - src_word
            cur_offset = math.modf(cur_x) % 8
            file1:write(string.format("and r9, r%d, #0x%x\n", cur_reg, 0xf << (cur_offset)*4))
            shift = (dst_pixel*4) - (cur_offset*4)
            if shift < 0 then
                file1:write(string.format("orr r8, r8, r9, lsr #%d\t; mask src pixel %d to dst pixel %d\n", -shift, math.modf(cur_x), dst_pixel))
            else
                file1:write(string.format("orr r8, r8, r9, lsl #%d\t; mask src pixel %d to dst pixel %d\n", shift, math.modf(cur_x), dst_pixel))
            end
    
            cur_x = cur_x + dx
        end
        file1:write(string.format("str r8, [r12], #4\n"))
        dst_x=dst_x+8
    end

    -- finish with final dst word
    dst_pixel_end=dst_x_end % 8
    if dst_pixel_end > 0 then
        
        src_x = cur_x
        src_word = src_x // 8

        if src_word == src_word_end then
            -- We need to reuse final source word from last dst word.
            if cur_reg == 0 then
                file1:write(string.format("; reuse src word %d in R0\n", src_word))
            else
                file1:write(string.format("mov r0, r%d\t\t; reuse src word %d\n", cur_reg, src_word))
            end
            src_word_start=src_word+1
        else
            src_word_start=src_word
        end
        file1:write(string.format("mov r8, #0\n"))

        src_x_end = src_x + (dst_pixel_end-1)*dx
        src_word_end = src_x_end // 8

        file1:write(string.format("; plot final word with dst pixels [%d, %d] from src pixels [%d, %d]\n",dst_x-dst_left, dst_x_end-1-dst_left, math.modf(src_x), math.modf(src_x_end)))

        if src_word_start==src_word_end then
            file1:write(string.format("ldr r%d, [r11], #4\t\t; src words [%d, %d]\n", src_word_start-src_word,src_word_start,src_word_end))
        else
            if src_word_start < src_word_end then
                file1:write(string.format("ldmia r11!, {r%d-r%d}\t; src words [%d, %d]\n", src_word_start-src_word, src_word_end-src_word,src_word_start,src_word_end))
            end
        end

        for dst_pixel=0,dst_pixel_end-1 do
            cur_word = cur_x // 8
            cur_reg = cur_word - src_word
            cur_offset = math.modf(cur_x) % 8
            file1:write(string.format("and r9, r%d, #0x%x\n", cur_reg, 0xf << (cur_offset)*4))
            shift = (dst_pixel*4) - (cur_offset*4)
            if shift < 0 then
                file1:write(string.format("orr r8, r8, r9, lsr #%d\t; mask src pixel %d to dst pixel %d\n", -shift, math.modf(cur_x), dst_pixel))
            else
                file1:write(string.format("orr r8, r8, r9, lsl #%d\t; mask src pixel %d to dst pixel %d\n", shift, math.modf(cur_x), dst_pixel))
            end
    
            cur_x = cur_x + dx
            dst_pixel = dst_pixel + 1
            dst_x = dst_x + 1
        end
        file1:write(string.format("str r8, [r12], #4\n"))
    end

    file1:write(string.format("mov pc, lr\n"))
end

file1:write(string.format("; jump table\n"))
file1:write(string.format("plot_width_table:\n"))

for width=min_width,source_width,2 do
    file1:write(string.format(".long plot_width_%d\n", width))
end

file1:write(string.format("; dy table\n"))
file1:write(string.format("plot_dy_table:\n"))

for width=min_width,max_width,width_step do
    -- step in src_x
    dx = source_width / width
    file1:write(string.format("FLOAT_TO_FP %f\n", dx))
end
