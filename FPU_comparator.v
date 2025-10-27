module FPU_comparator(
    input [31:0] A,
    input [31:0] B,
    input mode, 
    output reg [31:0] answer   
);

    reg a_sign, b_sign;
    reg [7:0] a_exp, b_exp;
    reg [22:0] a_fracrion, b_fraction;

    reg a_is_NaN,b_is_NaN;

    parameter fmax = 1'b1;
    parameter fmin = 1'b0;

//put ur design here 
    always @(*) begin
        // Unpack
        a_sign = A[31];
        b_sign = B[31];

        a_exp = A[30:23];
        b_exp = B[30:23];

        a_fracrion = A[22:0];
        b_fraction = B[22:0];

        a_is_NaN = (a_exp == 8'hFF) && (a_fracrion != 23'b0);
        b_is_NaN = (b_exp == 8'hFF) && (b_fraction != 23'b0);
        // Compare 
        // special case NaN

        if (a_is_NaN || b_is_NaN) begin
            answer = 32'hFFC00000;
        end

        else if (a_sign ^ b_sign) begin
            case (mode) 
                fmax: begin
                    answer = (a_sign) ? B : A;
                end
                fmin: begin
                    answer = (a_sign) ? A : B;
                end
            endcase
        end

        else if ( a_exp != b_exp ) begin
            case ({mode, a_sign}) 
                {fmax, 1'b0}, {fmin, 1'b1}: begin
                    answer = (a_exp > b_exp) ? A : B;
                end
                {fmin, 1'b0}, {fmax, 1'b1}: begin
                    answer = (a_exp > b_exp) ? B : A;
                end
            endcase
        end

        else if ( a_fracrion != b_fraction ) begin
            case ({mode, a_sign})
                {fmax, 1'b0}, {fmin, 1'b1}: begin
                    answer = (a_fracrion > b_fraction) ? A : B;
                end
                {fmin, 1'b0}, {fmax, 1'b1}: begin
                    answer = (a_fracrion > b_fraction) ? B : A;
                end
            endcase
        end

        else begin
            answer = A;
        end

    end
endmodule