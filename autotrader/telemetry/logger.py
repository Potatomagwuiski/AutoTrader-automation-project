"""
Telemetry and logging module.
"""

from rich.console import Console
from rich.theme import Theme
import logging
from pathlib import Path
from datetime import datetime
from autotrader.config.settings import settings

custom_theme = Theme({
    "info": "cyan",
    "warning": "yellow",
    "error": "bold red",
    "success": "bold green",
    "trade": "bold magenta",
    "risk": "bold yellow on red"
})

console = Console(theme=custom_theme)

def setup_logger(name: str = "autotrader") -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    
    if not logger.handlers:
        # File handler
        log_file = settings.LOG_DIR / f"autotrader_{datetime.now().strftime('%Y%m%d')}.log"
        fh = logging.FileHandler(log_file)
        fh.setLevel(logging.DEBUG)
        formatter = logging.Formatter(
            '%(asctime)s | %(levelname)-8s | %(name)s:%(funcName)s:%(lineno)d | %(message)s'
        )
        fh.setFormatter(formatter)
        logger.addHandler(fh)
        
    return logger

log = setup_logger()
