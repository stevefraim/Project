import os
import re
import tkinter as tk
from tkinter import messagebox, ttk
from tkinter.scrolledtext import ScrolledText

import psycopg2


DEFAULT_REGION = "us-east-1"
BG_COLOR = "#f3f6fb"
CARD_COLOR = "#ffffff"
ACCENT = "#0f62fe"
TEXT = "#1f2937"
MUTED = "#6b7280"


def normalize_display_name(value: str) -> str:
    value = value.strip()
    value = re.sub(r"[-_]+", " ", value)
    value = re.sub(r"\s+", " ", value)
    words = []
    for part in value.split(" "):
        if not part:
            continue
        words.append(part.upper() if len(part) == 1 else part.capitalize())
    return " ".join(words)


def normalize_slug(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-+", "-", value)
    return value.strip("-")


def load_dotenv_file(path: str) -> None:
    if not os.path.exists(path):
        return

    with open(path, "r", encoding="utf-8") as env_file:
        for raw_line in env_file:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue

            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")

            if key and key not in os.environ:
                os.environ[key] = value


class PgService:
    def __init__(self) -> None:
        self.conn: psycopg2.extensions.connection | None = None

    def connect(self) -> None:
        self.conn = psycopg2.connect(
            host=os.getenv("PG_HOST"),
            dbname=os.getenv("PG_DB"),
            user=os.getenv("PG_USER"),
            password=os.getenv("PG_PWD"),
            port=int(os.getenv("PG_PORT", 5432)),
        )

    def close(self) -> None:
        if self.conn:
            self.conn.close()


class FleetSignupApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Fleet Signup")
        self.geometry("760x500")
        self.minsize(700, 460)
        self.configure(bg=BG_COLOR)

        dotenv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
        load_dotenv_file(dotenv_path)

        self._build_styles()
        self._build_layout()

    def _build_styles(self) -> None:
        style = ttk.Style(self)
        style.theme_use("clam")

        style.configure("Page.TFrame", background=BG_COLOR)
        style.configure("Card.TFrame", background=CARD_COLOR)
        style.configure("Title.TLabel", background=CARD_COLOR, foreground=TEXT, font=("Helvetica", 18, "bold"))
        style.configure("Subtitle.TLabel", background=CARD_COLOR, foreground=MUTED, font=("Helvetica", 10))
        style.configure("Field.TLabel", background=CARD_COLOR, foreground=TEXT, font=("Helvetica", 10, "bold"))
        style.configure("Value.TLabel", background=CARD_COLOR, foreground=TEXT, font=("Consolas", 10))
        style.configure("TEntry", padding=8)
        style.configure("Primary.TButton", font=("Helvetica", 10, "bold"), padding=8)
        style.map(
            "Primary.TButton",
            background=[("active", ACCENT), ("!disabled", ACCENT)],
            foreground=[("!disabled", "white")],
        )
        style.configure("Secondary.TButton", padding=8)

    def _build_layout(self) -> None:
        page = ttk.Frame(self, style="Page.TFrame", padding=20)
        page.pack(fill="both", expand=True)

        card = ttk.Frame(page, style="Card.TFrame", padding=(24, 20))
        card.pack(fill="both", expand=True)

        ttk.Label(card, text="Fleet Signup", style="Title.TLabel").grid(row=0, column=0, columnspan=2, sticky="w")
        ttk.Label(
            card,
            text="Type fleet name with spaces. The rest will be generated automatically. Adjust if needed.",
            style="Subtitle.TLabel",
        ).grid(row=1, column=0, columnspan=2, sticky="w", pady=(2, 18))

        self.fleet_name_input_var = tk.StringVar()
        self.fleet_name_input_var.trace_add("write", self._on_name_change)

        ttk.Label(card, text="Fleet Name", style="Field.TLabel").grid(row=2, column=0, sticky="w", padx=(0, 14))
        name_entry = ttk.Entry(card, textvariable=self.fleet_name_input_var)
        name_entry.grid(row=2, column=1, sticky="ew")
        name_entry.focus_set()

        self.generated_vars = {
            "fleet_name": tk.StringVar(),
            "name": tk.StringVar(),
            "client_s3_bucket_region": tk.StringVar(value=DEFAULT_REGION),
            "client_s3_bucket": tk.StringVar(),
            "client_cdn": tk.StringVar(),
        }

        self._add_preview_row(card, "fleet_name", self.generated_vars["fleet_name"], 3)
        self._add_preview_row(card, "name", self.generated_vars["name"], 4)
        self._add_preview_row(card, "client_s3_bucket_region", self.generated_vars["client_s3_bucket_region"], 5)
        self._add_preview_row(card, "client_s3_bucket", self.generated_vars["client_s3_bucket"], 6)
        self._add_preview_row(card, "client_cdn", self.generated_vars["client_cdn"], 7)

        actions = ttk.Frame(card, style="Card.TFrame")
        actions.grid(row=8, column=0, columnspan=2, sticky="ew", pady=(16, 0))
        actions.columnconfigure(0, weight=1)

        ttk.Button(actions, text="Preview", style="Primary.TButton", command=self.preview_and_confirm).grid(
            row=0, column=1, sticky="e", padx=(8, 0)
        )
        ttk.Button(actions, text="Clear", style="Secondary.TButton", command=self.clear_fields).grid(
            row=0, column=2, sticky="e", padx=(8, 0)
        )

        card.grid_columnconfigure(1, weight=1)

    def _add_preview_row(self, parent: ttk.Frame, label: str, variable: tk.StringVar, row: int) -> None:
        ttk.Label(parent, text=label, style="Field.TLabel").grid(row=row, column=0, sticky="w", padx=(0, 14), pady=3)
        ttk.Label(parent, textvariable=variable, style="Value.TLabel").grid(row=row, column=1, sticky="w", pady=3)

    def _on_name_change(self, *_args) -> None:
        raw = self.fleet_name_input_var.get()
        fleet_name = normalize_display_name(raw)

        if not fleet_name:
            self.generated_vars["fleet_name"].set("")
            self.generated_vars["name"].set("")
            self.generated_vars["client_s3_bucket"].set("")
            self.generated_vars["client_cdn"].set("")
            self.generated_vars["client_s3_bucket_region"].set(DEFAULT_REGION)
            return

        slug = normalize_slug(fleet_name)
        domain = f"fleet{slug.replace('-', '')}.orca-ai.io"

        self.generated_vars["fleet_name"].set(fleet_name)
        self.generated_vars["name"].set(slug)
        self.generated_vars["client_s3_bucket_region"].set(DEFAULT_REGION)
        self.generated_vars["client_s3_bucket"].set(domain)
        self.generated_vars["client_cdn"].set(domain)

    def _collect_values(self) -> dict:
        return {
            "fleet_name": self.generated_vars["fleet_name"].get().strip(),
            "name": self.generated_vars["name"].get().strip(),
            "client_s3_bucket_region": self.generated_vars["client_s3_bucket_region"].get().strip(),
            "client_s3_bucket": self.generated_vars["client_s3_bucket"].get().strip(),
            "client_cdn": self.generated_vars["client_cdn"].get().strip(),
        }

    def _validate(self, values: dict) -> bool:
        if not values["fleet_name"]:
            messagebox.showerror("Missing fleet name", "Enter a fleet name first (example: Orix Maritime).")
            return False

        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", values["name"]):
            messagebox.showerror("Invalid generated slug", "Generated slug is invalid. Adjust the fleet name.")
            return False

        return True

    def preview_and_confirm(self) -> None:
        values = self._collect_values()
        if not self._validate(values):
            return

        sql_preview = (
            "INSERT INTO public.fleets (fleet_name, name, client_s3_bucket_region, client_s3_bucket, client_cdn)\n"
            "VALUES (%s, %s, %s, %s, %s);\n\n"
            f"Params:\n{(values['fleet_name'], values['name'], values['client_s3_bucket_region'], values['client_s3_bucket'], values['client_cdn'])}"
        )

        preview_window = tk.Toplevel(self)
        preview_window.title("Confirm Fleet Insert")
        preview_window.geometry("760x360")
        preview_window.configure(bg=BG_COLOR)
        preview_window.transient(self)
        preview_window.grab_set()

        frame = ttk.Frame(preview_window, style="Card.TFrame", padding=16)
        frame.pack(fill="both", expand=True, padx=14, pady=14)

        ttk.Label(frame, text="Review before insert", style="Title.TLabel").pack(anchor="w")
        ttk.Label(frame, text="This action will write a new row into the fleets table.", style="Subtitle.TLabel").pack(
            anchor="w", pady=(0, 10)
        )

        text = ScrolledText(frame, height=12, wrap="word", font=("Consolas", 10))
        text.insert("1.0", sql_preview)
        text.configure(state="disabled")
        text.pack(fill="both", expand=True)

        button_row = ttk.Frame(frame, style="Card.TFrame")
        button_row.pack(fill="x", pady=(12, 0))
        button_row.columnconfigure(0, weight=1)

        ttk.Button(button_row, text="Cancel", style="Secondary.TButton", command=preview_window.destroy).grid(
            row=0, column=1, sticky="e"
        )

        def confirm_insert() -> None:
            preview_window.destroy()
            self.insert_into_db(values)

        ttk.Button(button_row, text="Confirm Insert", style="Primary.TButton", command=confirm_insert).grid(
            row=0, column=2, sticky="e", padx=(8, 0)
        )

    def insert_into_db(self, values: dict) -> None:
        pg = PgService()
        try:
            pg.connect()
            with pg.conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO public.fleets
                    (fleet_name, name, client_s3_bucket_region, client_s3_bucket, client_cdn)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING fleet_id
                    """,
                    (
                        values["fleet_name"],
                        values["name"],
                        values["client_s3_bucket_region"],
                        values["client_s3_bucket"],
                        values["client_cdn"],
                    ),
                )
                new_fleet_id = cur.fetchone()[0]
            pg.conn.commit()
        except Exception as exc:
            if pg.conn:
                pg.conn.rollback()
            messagebox.showerror("Insert failed", str(exc))
            return
        finally:
            pg.close()

        messagebox.showinfo("Success", f"Inserted successfully. New fleet_id: {new_fleet_id}")
        self.clear_fields()

    def clear_fields(self) -> None:
        self.fleet_name_input_var.set("")


if __name__ == "__main__":
    app = FleetSignupApp()
    app.mainloop()
