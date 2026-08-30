"""
Symbolic / Genetic Strategy Mutation Engine.
Generates evolutionary parameter perturbations to explore unmapped alpha opportunities.
"""

import random
from typing import Type
from autotrader.strategies.base import BaseStrategy

class StrategyMutator:
    def __init__(self, mutation_rate: float = 0.25):
        self.mutation_rate = mutation_rate

    def mutate_parameters(self, base_params: dict) -> dict:
        """
        Applies stochastic variations to numerical hyperparameters.
        """
        mutated = dict(base_params)
        for key, val in base_params.items():
            if isinstance(val, bool):
                if random.random() < 0.1:
                    mutated[key] = not val
            elif isinstance(val, int):
                if random.random() < self.mutation_rate:
                    delta = random.choice([-2, -1, 1, 2])
                    mutated[key] = max(1, val + delta)
            elif isinstance(val, float):
                if random.random() < self.mutation_rate:
                    factor = random.uniform(0.85, 1.15)
                    mutated[key] = round(val * factor, 3)

        return mutated

    def generate_population(self, base_params: dict, population_size: int = 10) -> list[dict]:
        population = [base_params]
        for _ in range(population_size - 1):
            population.append(self.mutate_parameters(base_params))
        return population
