"""
Autonomous Profit Harvesting & Dynamic Milestone Scaling Advisor.
Automates the 'High-Water Mark Cash Buffer Protocol':
- Automatically scales your living salary withdrawal as the account hits major milestones ($500k -> $1M -> $2.5M -> $5M).
- Calculates exact safe harvestable surplus without disrupting the 2-position compounding engine.
- Enforces the 1-Year Living Buffer & Capital Preservation rules during drawdowns.
"""

from datetime import datetime
from pydantic import BaseModel, Field
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

class MilestoneTier(BaseModel):
    tier_name: str
    min_equity: float
    annual_salary: float
    withdrawal_rate_pct: float

# Default Institutional Milestone Scaling Ladder
DEFAULT_MILESTONES = [
    MilestoneTier(tier_name="Tier 1: Foundation Freedom", min_equity=500000.0, annual_salary=80000.0, withdrawal_rate_pct=16.0),
    MilestoneTier(tier_name="Tier 2: Millionaire Status", min_equity=1000000.0, annual_salary=150000.0, withdrawal_rate_pct=15.0),
    MilestoneTier(tier_name="Tier 3: Multi-Millionaire", min_equity=2500000.0, annual_salary=300000.0, withdrawal_rate_pct=12.0),
    MilestoneTier(tier_name="Tier 4: Generational Wealth", min_equity=5000000.0, annual_salary=600000.0, withdrawal_rate_pct=12.0),
    MilestoneTier(tier_name="Tier 5: Institutional Empire", min_equity=10000000.0, annual_salary=1200000.0, withdrawal_rate_pct=12.0),
]

class HarvestDecision(BaseModel):
    status: str  # 'HARVEST_READY', 'BUFFER_SECURED', 'PRESERVATION_MODE'
    current_equity: float
    high_water_mark: float
    drawdown_pct: float
    current_tier_name: str
    next_tier_name: str
    next_tier_target: float
    recommended_harvest_amount: float
    safe_compounding_capital: float
    annual_salary_target: float
    harvest_reason: str
    action_items: list[str] = Field(default_factory=list)

class ProfitHarvestAdvisor:
    def __init__(
        self,
        base_annual_salary: float = 80000.0,
        locked_growth_floor: float = 100000.0,  # Minimum core principal to never touch
        min_harvest_chunk: float = 5000.0,       # Minimum transfer amount to avoid micro-withdrawals
        surplus_harvest_pct: float = 0.50,       # Takes 50% of new high-water profits, leaves 50% to compound
        milestones: list[MilestoneTier] | None = None
    ):
        self.base_annual_salary = base_annual_salary
        self.locked_growth_floor = locked_growth_floor
        self.min_harvest_chunk = min_harvest_chunk
        self.surplus_harvest_pct = surplus_harvest_pct
        self.milestones = milestones or DEFAULT_MILESTONES
        self.high_water_mark = locked_growth_floor
        self.total_harvested_ytd = 0.0

    def get_dynamic_tier(self, equity: float) -> tuple[MilestoneTier, MilestoneTier | None]:
        """Calculates active milestone tier and next upcoming tier."""
        current_tier = MilestoneTier(
            tier_name="Accumulation Phase",
            min_equity=0.0,
            annual_salary=self.base_annual_salary,
            withdrawal_rate_pct=15.0
        )
        next_tier = self.milestones[0]

        for i, m in enumerate(self.milestones):
            if equity >= m.min_equity:
                current_tier = m
                next_tier = self.milestones[i + 1] if i + 1 < len(self.milestones) else None

        return current_tier, next_tier

    def evaluate_harvest(
        self,
        current_equity: float,
        withdrawn_ytd: float = 0.0,
        is_bear_regime: bool = False
    ) -> HarvestDecision:
        """
        Autonomously calculates scaled safe withdrawal amounts based on live equity and high-water milestones.
        """
        self.total_harvested_ytd = withdrawn_ytd

        # Update High-Water Mark
        if current_equity > self.high_water_mark:
            self.high_water_mark = current_equity

        # Determine dynamic tier & salary target
        current_tier, next_tier = self.get_dynamic_tier(current_equity)
        dynamic_salary_target = current_tier.annual_salary

        next_tier_name = next_tier.tier_name if next_tier else "Top Tier Achieved"
        next_tier_target = next_tier.min_equity if next_tier else current_equity

        # Drawdown calculation
        dd_amount = self.high_water_mark - current_equity
        dd_pct = (dd_amount / self.high_water_mark) if self.high_water_mark > 0 else 0.0

        # Case 1: In a Bear Market or significant drawdown (>5%) -> Preservation Mode
        if is_bear_regime or dd_pct > 0.05:
            return HarvestDecision(
                status="PRESERVATION_MODE",
                current_equity=current_equity,
                high_water_mark=self.high_water_mark,
                drawdown_pct=dd_pct,
                current_tier_name=current_tier.tier_name,
                next_tier_name=next_tier_name,
                next_tier_target=next_tier_target,
                recommended_harvest_amount=0.0,
                safe_compounding_capital=current_equity,
                annual_salary_target=dynamic_salary_target,
                harvest_reason=f"Account is in {dd_pct:.1%} drawdown from peak (${self.high_water_mark:,.2f}) or Bear Regime active. Keep all capital in trading/cash shield.",
                action_items=[
                    "🛡️ Take $0.00 from trading account.",
                    "🏦 Live off your pre-funded 1-Year Bank Buffer.",
                    "⏳ Let bot protect capital until the next secular bull wave."
                ]
            )

        # Case 2: Above core baseline & High-Water Mark peak profit surge -> Harvest Ready
        surplus_above_floor = max(0.0, current_equity - self.locked_growth_floor)
        salary_remaining_needed = max(0.0, dynamic_salary_target - self.total_harvested_ytd)
        potential_harvest = surplus_above_floor * self.surplus_harvest_pct

        if potential_harvest >= self.min_harvest_chunk and salary_remaining_needed > 0 and dd_pct <= 0.02:
            harvest_amount = min(potential_harvest, salary_remaining_needed)
            harvest_amount = round(harvest_amount / 100) * 100.0

            return HarvestDecision(
                status="HARVEST_READY",
                current_equity=current_equity,
                high_water_mark=self.high_water_mark,
                drawdown_pct=dd_pct,
                current_tier_name=current_tier.tier_name,
                next_tier_name=next_tier_name,
                next_tier_target=next_tier_target,
                recommended_harvest_amount=harvest_amount,
                safe_compounding_capital=current_equity - harvest_amount,
                annual_salary_target=dynamic_salary_target,
                harvest_reason=f"🚀 {current_tier.tier_name} profit surge detected! Safe to harvest scaled living salary.",
                action_items=[
                    f"💰 Transfer exactly ${harvest_amount:,.2f} from Alpaca to your Living Bank Account.",
                    f"📈 Remaining ${current_equity - harvest_amount:,.2f} stays in bot for full compounding acceleration.",
                    f"🏆 Active Status: {current_tier.tier_name} (${dynamic_salary_target:,.0f}/yr target).",
                    f"🎯 Next Milestone: {next_tier_name} at ${next_tier_target:,.0f}."
                ]
            )

        # Case 3: Buffer already fully funded or below harvest threshold
        return HarvestDecision(
            status="BUFFER_SECURED",
            current_equity=current_equity,
            high_water_mark=self.high_water_mark,
            drawdown_pct=dd_pct,
            current_tier_name=current_tier.tier_name,
            next_tier_name=next_tier_name,
            next_tier_target=next_tier_target,
            recommended_harvest_amount=0.0,
            safe_compounding_capital=current_equity,
            annual_salary_target=dynamic_salary_target,
            harvest_reason=f"Annual {current_tier.tier_name} salary target (${dynamic_salary_target:,.0f}) is fully secured, or account is compounding toward {next_tier_name}.",
            action_items=[
                "🌱 No withdrawal needed right now.",
                f"🚀 100% of trading gains are compounding toward {next_tier_name} (${next_tier_target:,.0f})."
            ]
        )

    def print_harvest_dashboard(self, decision: HarvestDecision) -> None:
        """Renders an institutional-grade harvest telemetry panel to console."""
        console = Console()

        color = "green" if decision.status == "HARVEST_READY" else ("yellow" if decision.status == "BUFFER_SECURED" else "red")
        icon = "💰" if decision.status == "HARVEST_READY" else ("🛡️" if decision.status == "PRESERVATION_MODE" else "🌱")

        table = Table(show_header=True, header_style="bold cyan", border_style="dim")
        table.add_column("Metric", style="bold white")
        table.add_column("Value", style="bold yellow")

        table.add_row("Live Portfolio Equity", f"${decision.current_equity:,.2f}")
        table.add_row("All-Time Peak (High-Water Mark)", f"${decision.high_water_mark:,.2f}")
        table.add_row("Current Tier Level", f"[bold cyan]{decision.current_tier_name}[/bold cyan]")
        table.add_row("Dynamic Annual Salary Target", f"[bold green]${decision.annual_salary_target:,.2f}/yr[/bold green]")
        table.add_row("Harvested YTD", f"${self.total_harvested_ytd:,.2f}")
        table.add_row("Recommended Instant Harvest", f"[bold green]${decision.recommended_harvest_amount:,.2f}[/bold green]" if decision.recommended_harvest_amount > 0 else "$0.00")
        table.add_row("Safe Active Trading Capital", f"${decision.safe_compounding_capital:,.2f}")
        table.add_row("Next Tier Upgrade Target", f"{decision.next_tier_name} (${decision.next_tier_target:,.2f})")

        console.print("\n")
        console.print(Panel(
            table,
            title=f"[bold {color}]{icon} AUTONOMOUS PROFIT HARVEST ADVISOR: {decision.status}[/bold {color}]",
            subtitle=f"[white]{decision.harvest_reason}[/white]",
            border_style=color
        ))

        console.print("[bold cyan]Recommended Next Action:[/bold cyan]")
        for act in decision.action_items:
            console.print(f"  {act}")
        console.print("\n")
