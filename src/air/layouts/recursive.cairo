mod autogenerated;
mod constants;
mod global_values;
mod public_input;
mod traces;

use cairo_verifier::{
    air::{
        constants::{SHIFT_POINT_X, SHIFT_POINT_Y},
        layouts::recursive::{
            autogenerated::{eval_composition_polynomial_inner, eval_oods_polynomial_inner},
            global_values::{GlobalValues, InteractionElements, EcPoint},
            public_input::RecursivePublicInputImpl,
            constants::{
                PUBLIC_MEMORY_STEP, DILUTED_N_BITS, DILUTED_SPACING, PEDERSEN_BUILTIN_RATIO,
                PEDERSEN_BUILTIN_REPETITIONS, segments,
            },
        },
        air::{AIRComposition, AIROods}, diluted::get_diluted_product,
        periodic_columns::{eval_pedersen_x, eval_pedersen_y},
        public_input::{PublicInput, get_public_memory_product_ratio}
    },
    common::{math::{Felt252Div, Felt252PartialOrd, pow}, asserts::assert_range_u128}
};

impl RecursiveAIRCompositionImpl of AIRComposition<InteractionElements, PublicInput> {
    fn eval_composition_polynomial(
        interaction_elements: InteractionElements,
        public_input: @PublicInput,
        mask_values: Span<felt252>,
        constraint_coefficients: Span<felt252>,
        point: felt252,
        trace_domain_size: felt252,
        trace_generator: felt252
    ) -> felt252 {
        let memory_z = interaction_elements.memory_multi_column_perm_perm_interaction_elm;
        let memory_alpha = interaction_elements.memory_multi_column_perm_hash_interaction_elm0;

        // Public memory
        let public_memory_column_size = trace_domain_size / PUBLIC_MEMORY_STEP;
        assert_range_u128(public_memory_column_size);
        let public_memory_prod_ratio = get_public_memory_product_ratio(
            public_input, memory_z, memory_alpha, public_memory_column_size
        );

        // Diluted
        let diluted_z = interaction_elements.diluted_check_interaction_z;
        let diluted_alpha = interaction_elements.diluted_check_interaction_alpha;
        let diluted_prod = get_diluted_product(
            DILUTED_N_BITS, DILUTED_SPACING, diluted_z, diluted_alpha
        );

        // Periodic columns
        let n_steps = pow(2, *public_input.log_n_steps);
        let n_pedersen_hash_copies = n_steps
            / (PEDERSEN_BUILTIN_RATIO * PEDERSEN_BUILTIN_REPETITIONS);
        assert_range_u128(n_pedersen_hash_copies);
        let pedersen_point = pow(point, n_pedersen_hash_copies);
        let pedersen_points_x = eval_pedersen_x(pedersen_point);
        let pedersen_points_y = eval_pedersen_y(pedersen_point);

        let global_values = GlobalValues {
            trace_length: trace_domain_size,
            initial_pc: *public_input.segments.at(segments::PROGRAM).begin_addr,
            final_pc: *public_input.segments.at(segments::PROGRAM).stop_ptr,
            initial_ap: *public_input.segments.at(segments::EXECUTION).begin_addr,
            final_ap: *public_input.segments.at(segments::EXECUTION).stop_ptr,
            initial_pedersen_addr: *public_input.segments.at(segments::PEDERSEN).begin_addr,
            initial_range_check_addr: *public_input.segments.at(segments::RANGE_CHECK).begin_addr,
            initial_bitwise_addr: *public_input.segments.at(segments::BITWISE).begin_addr,
            range_check_min: *public_input.range_check_min,
            range_check_max: *public_input.range_check_max,
            offset_size: 0x10000, // 2**16
            half_offset_size: 0x8000, // 2**15
            pedersen_shift_point: EcPoint { x: SHIFT_POINT_X, y: SHIFT_POINT_Y },
            pedersen_points_x,
            pedersen_points_y,
            memory_multi_column_perm_perm_interaction_elm: memory_z,
            memory_multi_column_perm_hash_interaction_elm0: memory_alpha,
            range_check16_perm_interaction_elm: interaction_elements
                .range_check16_perm_interaction_elm,
            diluted_check_permutation_interaction_elm: interaction_elements
                .diluted_check_permutation_interaction_elm,
            diluted_check_interaction_z: diluted_z,
            diluted_check_interaction_alpha: diluted_alpha,
            memory_multi_column_perm_perm_public_memory_prod: public_memory_prod_ratio,
            range_check16_perm_public_memory_prod: 1,
            diluted_check_first_elm: 0,
            diluted_check_permutation_public_memory_prod: 1,
            diluted_check_final_cum_val: diluted_prod
        };

        eval_composition_polynomial_inner(
            mask_values, constraint_coefficients, point, trace_generator, global_values
        )
    }
}

impl RecursiveAIROodsImpl of AIROods {
    fn eval_oods_polynomial(
        column_values: Span<felt252>,
        oods_values: Span<felt252>,
        constraint_coefficients: Span<felt252>,
        point: felt252,
        oods_point: felt252,
        trace_generator: felt252,
    ) -> felt252 {
        eval_oods_polynomial_inner(
            column_values, oods_values, constraint_coefficients, point, oods_point, trace_generator,
        )
    }
}
