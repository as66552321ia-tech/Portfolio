#include "httplib.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
#include <cstdlib>

struct Entry
{
    int start_min = 0; // minutes since midnight
    int end_min = 0;   // minutes since midnight
    int break_min = 0; // unpaid break minutes
    double rate = 0.0; // hourly rate
};

static std::mutex g_mu;
static std::unordered_map<std::string, Entry> g_entries; //  YYYY-MM-DD
static const char *kDataFile = "data.csv";

static std::string json_escape(const std::string &s)
{
    std::ostringstream o;
    for (char c : s)
    {
        switch (c)
        {
        case '\\':
            o << "\\\\";
            break;
        case '"':
            o << "\\\"";
            break;
        case '\n':
            o << "\\n";
            break;
        case '\r':
            o << "\\r";
            break;
        case '\t':
            o << "\\t";
            break;
        default:
            o << c;
            break;
        }
    }

    return o.str();
}

static std::string url_decode(const std::string &s)
{
    std::string out;
    out.reserve(s.size());

    for (size_t i = 0; i < s.size(); i++)
    {
        if (s[i] == '+')
        {
            out.push_back(' ');
        }
        else if (s[i] == '%' && i + 2 < s.size())
        {
            auto hex = s.substr(i + 1, 2);
            char *end = nullptr;
            long v = std::strtol(hex.c_str(), &end, 16);

            if (end && *end == '\0')
            {
                out.push_back(static_cast<char>(v));
                i += 2;
            }
            else
            {
                out.push_back(s[i]);
            }
        }
        else
        {
            out.push_back(s[i]);
        }
    }

    return out;
}

static std::unordered_map<std::string, std::string> parse_form_urlencoded(const std::string &body)
{
    std::unordered_map<std::string, std::string> m;
    size_t start = 0;

    while (start < body.size())
    {
        size_t amp = body.find('&', start);

        if (amp == std::string::npos)
        {
            amp = body.size();
        }

        auto kv = body.substr(start, amp - start);

        size_t eq = kv.find('=');
        std::string key = url_decode(kv.substr(0, eq));
        std::string val = (eq == std::string::npos) ? "" : url_decode(kv.substr(eq + 1));

        if (!key.empty())
        {
            m[key] = val;
        }

        start = amp + 1;
    }

    return m;
}

static bool to_int(const std::unordered_map<std::string, std::string> &m, const std::string &key, int &out, std::string &err, bool required, int default_value = 0)
{
    auto it = m.find(key);

    if (it == m.end() || it->second.empty())
    {
        if (required)
        {
            err = "Missing field: " + key;

            return false;
        }

        out = default_value;

        return true;
    }

    try
    {
        size_t idx = 0;
        long v = std::stol(it->second, &idx);

        if (idx != it->second.size())
        {
            err = "Invalid integer in field: " + key;

            return false;
        }

        out = static_cast<int>(v);

        return true;
    }

    catch (...)
    {
        err = "Invalid integer in field: " + key;

        return false;
    }
}

static bool to_double(const std::unordered_map<std::string, std::string> &m, const std::string &key, double &out, std::string &err, bool required, double default_value = 0.0)
{
    auto it = m.find(key);

    if (it == m.end() || it->second.empty())
    {
        if (required)
        {
            err = "Missing field: " + key;

            return false;
        }

        out = default_value;

        return true;
    }

    try
    {
        size_t idx = 0;
        out = std::stod(it->second, &idx);

        if (idx != it->second.size())
        {
            err = "Invalid number in field: " + key;

            return false;
        }

        return true;
    }

    catch (...)
    {
        err = "Invalid number in field: " + key;

        return false;
    }
}

static std::string trim(const std::string &s)
{
    size_t a = 0, b = s.size();

    while (a < b && std::isspace(static_cast<unsigned char>(s[a])))
    {
        a++;
    }
    while (b > a && std::isspace(static_cast<unsigned char>(s[b - 1])))
    {
        b--;
    }

    return s.substr(a, b - a);
}

static std::string lower(std::string s)
{
    for (auto &c : s)
    {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }

    return s;
}

static bool is_valid_date_yyyy_mm_dd(const std::string &d)
{
    if (d.size() != 10)
    {
        return false;
    }

    if (!(std::isdigit(d[0]) && std::isdigit(d[1]) && std::isdigit(d[2]) && std::isdigit(d[3])))
    {
        return false;
    }

    if (d[4] != '-')
    {
        return false;
    }

    if (!(std::isdigit(d[5]) && std::isdigit(d[6])))
    {
        return false;
    }

    if (d[7] != '-')
    {
        return false;
    }

    if (!(std::isdigit(d[8]) && std::isdigit(d[9])))
    {
        return false;
    }

    int y = std::stoi(d.substr(0, 4));
    int m = std::stoi(d.substr(5, 2));
    int day = std::stoi(d.substr(8, 2));

    if (y < 1900 || y > 3000)
    {
        return false;
    }

    if (m < 1 || m > 12)
    {
        return false;
    }

    if (day < 1 || day > 31)
    {
        return false;
    } // basic check

    return true;
}

// Accepts: "09:00", "17:30", "9am", "9:00am", "5 pm", "12:15PM"
static std::optional<int> parse_time_to_minutes(const std::string &input)
{
    std::string s = lower(trim(input));

    if (s.empty())
    {
        return std::nullopt;
    }

    bool has_am = false, has_pm = false;

    // remove spaces
    s.erase(std::remove_if(s.begin(), s.end(), [](unsigned char c)
                           { return std::isspace(c); }),
            s.end());

    if (s.size() >= 2)
    {
        auto suf = s.substr(s.size() - 2);

        if (suf == "am")
        {
            has_am = true;
            s = s.substr(0, s.size() - 2);
        }
        else if (suf == "pm")
        {
            has_pm = true;
            s = s.substr(0, s.size() - 2);
        }
    }

    int hh = 0, mm = 0;

    auto colon = s.find(':');
    if (colon == std::string::npos)
    {
        // "9" -> 9:00
        if (s.empty() || !std::all_of(s.begin(), s.end(), ::isdigit))
        {
            return std::nullopt;
        }

        hh = std::stoi(s);
        mm = 0;
    }
    else
    {
        auto h = s.substr(0, colon);
        auto m = s.substr(colon + 1);

        if (h.empty() || m.empty())
        {
            return std::nullopt;
        }

        if (!std::all_of(h.begin(), h.end(), ::isdigit))
        {
            return std::nullopt;
        }

        if (!std::all_of(m.begin(), m.end(), ::isdigit))
        {
            return std::nullopt;
        }

        hh = std::stoi(h);
        mm = std::stoi(m);
    }

    if (mm < 0 || mm > 59)
    {
        return std::nullopt;
    }

    if (has_am || has_pm)
    {
        // 12-hour
        if (hh < 1 || hh > 12)
        {
            return std::nullopt;
        }

        if (has_am)
        {
            if (hh == 12)
            {
                hh = 0;
            }
        }
        else
        {
            // pm
            if (hh != 12)
            {
                hh += 12;
            }
        }
    }
    else
    {
        // 24-hour
        if (hh < 0 || hh > 23)
        {
            return std::nullopt;
        }
    }

    return hh * 60 + mm;
}

static int work_minutes(const Entry &e)
{
    int start = e.start_min;
    int end = e.end_min;
    int dur = 0;

    if (end >= start)
    {
        dur = end - start;
    }
    else
    {
        dur = (24 * 60 - start) + end;
    } // overnight shift

    dur -= std::max(0, e.break_min);

    return std::max(0, dur);
}

static double round2(double x)
{
    return std::round(x * 100.0) / 100.0;
}

static std::string minutes_to_hhmm(int mins)
{
    mins %= (24 * 60);

    if (mins < 0)
    {
        mins += 24 * 60;
    }

    int h = mins / 60;
    int m = mins % 60;
    std::ostringstream o;

    o << std::setw(2) << std::setfill('0') << h << ":" << std::setw(2) << std::setfill('0') << m;

    return o.str();
}

static void save_csv_locked()
{
    std::ofstream f(kDataFile, std::ios::trunc);
    if (!f)
    {
        return;
    }

    // header
    f << "date,start_min,end_min,break_min,rate\n";

    // stable order
    std::vector<std::string> keys;
    keys.reserve(g_entries.size());

    for (auto &kv : g_entries)
    {
        keys.push_back(kv.first);
    }

    std::sort(keys.begin(), keys.end());

    for (auto &d : keys)
    {
        const auto &e = g_entries[d];
        f << d << "," << e.start_min << "," << e.end_min << "," << e.break_min << "," << std::fixed << std::setprecision(6) << e.rate << "\n";
    }
}

static void load_csv()
{
    std::lock_guard<std::mutex> lk(g_mu);
    g_entries.clear();

    std::ifstream f(kDataFile);
    if (!f)
    {
        return;
    }

    std::string line;
    bool first = true;

    while (std::getline(f, line))
    {
        if (first)
        {
            first = false;
            continue;
        }

        if (trim(line).empty())
        {
            continue;
        }

        std::vector<std::string> cols;
        std::string cur;
        std::istringstream in(line);

        while (std::getline(in, cur, ','))
        {
            cols.push_back(trim(cur));
        }

        if (cols.size() != 5)
        {
            continue;
        }

        const std::string &date = cols[0];

        if (!is_valid_date_yyyy_mm_dd(date))
        {
            continue;
        }

        Entry e;

        try
        {
            e.start_min = std::stoi(cols[1]);
            e.end_min = std::stoi(cols[2]);
            e.break_min = std::stoi(cols[3]);
            e.rate = std::stod(cols[4]);
        }

        catch (...)
        {
            continue;
        }

        if (e.start_min < 0 || e.start_min >= 24 * 60)
        {
            continue;
        }

        if (e.end_min < 0 || e.end_min >= 24 * 60)
        {
            continue;
        }

        if (e.break_min < 0 || e.break_min > 24 * 60)
        {
            continue;
        }

        if (e.rate < 0)
        {
            continue;
        }

        g_entries[date] = e;
    }
}

int main()
{
    load_csv();

    using namespace std;
    using namespace httplib;

    Server svr;

    // POST /api/entry  (create/update a day entry)
    svr.Post("/api/entry", [](const Request &req, Response &res)
             {
        auto form = parse_form_urlencoded(req.body);
        std::string err;

        auto itDate = form.find("date");

        if (itDate == form.end() || itDate->second.empty()) 
        {
            err = "Missing field: date (YYYY-MM-DD)";
        } 
        else if (!is_valid_date_yyyy_mm_dd(itDate->second)) 
        {
            err = "Invalid date format. Use YYYY-MM-DD";
        }

        if (!err.empty()) 
        {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"" + json_escape(err) + "\"}", "application/json");

            return;
        }

        const std::string date = itDate->second;

        auto itStart = form.find("start");
        auto itEnd = form.find("end");

        if (itStart == form.end() || trim(itStart->second).empty())
        {
            err = "Missing field: start";
        }

        else if (itEnd == form.end() || trim(itEnd->second).empty()) 
        {
            err = "Missing field: end";
        }
        
        if (!err.empty()) {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"" + json_escape(err) + "\"}", "application/json");

            return;
        }

        auto start_opt = parse_time_to_minutes(itStart->second);
        auto end_opt = parse_time_to_minutes(itEnd->second);

        if (!start_opt || !end_opt) {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"Invalid time. Examples: 9:00am, 17:00, 5 pm\"}", "application/json");

            return;
        }

        int break_min = 0;
        (void)to_int(form, "break_min", break_min, err, false, 0);

        if (!err.empty())
         {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"" + json_escape(err) + "\"}", "application/json");

            return;
        }

        if (break_min < 0 || break_min > 24 * 60) 
        {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"break_min out of range\"}", "application/json");

            return;
        }

        double rate = 0.0;

        if (!to_double(form, "rate", rate, err, true)) 
        {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"" + json_escape(err) + "\"}", "application/json");

            return;
        }

        if (rate < 0) 
        {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"rate must be >= 0\"}", "application/json");

            return;
        }

        Entry e;
        e.start_min = *start_opt;
        e.end_min = *end_opt;
        e.break_min = break_min;
        e.rate = rate;

        const int mins = work_minutes(e);
        const double hours = mins / 60.0;
        const double pay = round2(hours * e.rate);

        {
            std::lock_guard<std::mutex> lk(g_mu);
            g_entries[date] = e;
            save_csv_locked();
        }

        std::ostringstream json;
        json << "{"
             << "\"ok\":true,"
             << "\"date\":\"" << json_escape(date) << "\","
             << "\"start\":\"" << json_escape(minutes_to_hhmm(e.start_min)) << "\","
             << "\"end\":\"" << json_escape(minutes_to_hhmm(e.end_min)) << "\","
             << "\"break_min\":" << e.break_min << ","
             << "\"minutes_worked\":" << mins << ","
             << "\"hours\":" << std::fixed << std::setprecision(2) << round2(hours) << ","
             << "\"rate\":" << std::fixed << std::setprecision(2) << round2(e.rate) << ","
             << "\"pay\":" << std::fixed << std::setprecision(2) << pay
             << "}";

        res.set_content(json.str(), "application/json"); });

    // DELETE /api/entry?date=YYYY-MM-DD  (remove a day entry)
    svr.Delete("/api/entry", [](const Request &req, Response &res)
               {
        auto date = req.get_param_value("date");

        if (!is_valid_date_yyyy_mm_dd(date)) 
        {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"Invalid date\"}", "application/json");

            return;
        }

        bool existed = false;
        {
            std::lock_guard<std::mutex> lk(g_mu);
            existed = (g_entries.erase(date) > 0);
            save_csv_locked();
        }

        res.set_content(std::string("{\"ok\":true,\"deleted\":") + (existed ? "true" : "false") + "}", "application/json"); });

    // GET /api/month?year=2026&month=1  (returns all entries in that month + totals)
    svr.Get("/", [](const Request &, Response &res)
            {
    const char* page = R"HTML(
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Salary Calculator</title>
  <style>
    :root { --bg:#0b1220; --card:#121a2b; --muted:#9fb0d0; --text:#e8eefc; --accent:#6ea8fe; --bad:#ff6b6b; --ok:#3ddc97; }
    * { box-sizing: border-box; font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; }
    body { margin:0; background: linear-gradient(180deg, var(--bg), #060a12); color: var(--text); }
    .wrap { max-width: 980px; margin: 0 auto; padding: 20px; }
    h1 { margin: 6px 0 14px; font-size: 20px; }
    .grid { display: grid; gap: 14px; grid-template-columns: 1fr; }
    @media (min-width: 860px) { .grid { grid-template-columns: 360px 1fr; } }
    .card { background: rgba(18,26,43,0.9); border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; padding: 14px; }
    label { display:block; font-size: 12px; color: var(--muted); margin: 10px 0 6px; }
    input, select { width:100%; padding: 10px 10px; border-radius: 10px; border:1px solid rgba(255,255,255,0.12); background:#0d1424; color: var(--text); }
    input::placeholder { color: rgba(159,176,208,0.65); }
    .row { display:flex; gap: 10px; }
    .row > * { flex:1; }
    button { cursor:pointer; padding: 10px 12px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.14); background: #18233a; color: var(--text); }
    button.primary { background: #1c3d74; border-color: rgba(110,168,254,0.35); }
    button.danger { background: #3a1620; border-color: rgba(255,107,107,0.35); }
    button:disabled { opacity:0.6; cursor:not-allowed; }
    .msg { margin-top: 10px; font-size: 13px; }
    .msg.ok { color: var(--ok); }
    .msg.bad { color: var(--bad); }
    table { width:100%; border-collapse: collapse; margin-top: 10px; }
    th, td { padding: 10px 8px; border-bottom: 1px solid rgba(255,255,255,0.08); text-align:left; font-size: 13px; }
    th { color: var(--muted); font-weight: 600; }
    .totals { display:flex; gap: 12px; flex-wrap: wrap; margin-top: 8px; color: var(--muted); font-size: 13px; }
    .pill { padding: 6px 10px; border: 1px solid rgba(255,255,255,0.10); border-radius: 999px; background: rgba(13,20,36,0.7); }
    .actions { display:flex; gap: 10px; margin-top: 12px; }
    .small { font-size:12px; color: var(--muted); margin-top: 6px; line-height: 1.35; }
    .right { text-align:right; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>Salary Calculator</h1>

    <div class="grid">
      <div class="card">
        <div class="row">
          <div>
            <label for="year">Year</label>
            <input id="year" type="number" min="1900" max="3000" />
          </div>
          <div>
            <label for="month">Month</label>
            <select id="month">
              <option value="1">Jan</option><option value="2">Feb</option><option value="3">Mar</option><option value="4">Apr</option>
              <option value="5">May</option><option value="6">Jun</option><option value="7">Jul</option><option value="8">Aug</option>
              <option value="9">Sep</option><option value="10">Oct</option><option value="11">Nov</option><option value="12">Dec</option>
            </select>
          </div>
        </div>

        <div class="actions">
          <button id="refresh" class="primary">Refresh month</button>
        </div>

        <hr style="border:none;border-top:1px solid rgba(255,255,255,0.08); margin:14px 0;">

        <label for="date">Date</label>
        <input id="date" type="date" />

        <div class="row">
          <div>
            <label for="start">Start (e.g. 9:00am or 17:00)</label>
            <input id="start" placeholder="9:00am" />
          </div>
          <div>
            <label for="end">End (e.g. 5pm or 18:30)</label>
            <input id="end" placeholder="5:00pm" />
          </div>
        </div>

        <div class="row">
          <div>
            <label for="break_min">Break minutes (unpaid)</label>
            <input id="break_min" type="number" min="0" max="1440" value="0" />
          </div>
          <div>
            <label for="rate">Hourly rate</label>
            <input id="rate" type="number" min="0" step="0.01" placeholder="20.00" />
          </div>
        </div>

        <div class="actions">
          <button id="save" class="primary">Save / Update day</button>
          <button id="del" class="danger">Delete day</button>
        </div>

        <div id="msg" class="msg"></div>
        <div class="small">
          Tips: times accept <code>09:00</code>, <code>9am</code>, <code>9:00am</code>, <code>5 pm</code>, <code>17:30</code>.<br/>
          Overnight shifts are supported (end earlier than start).
        </div>
      </div>

      <div class="card">
        <div class="totals">
          <div class="pill" id="t_minutes">Minutes: —</div>
          <div class="pill" id="t_hours">Hours: —</div>
          <div class="pill" id="t_pay">Pay: —</div>
        </div>

        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Start</th>
              <th>End</th>
              <th class="right">Break</th>
              <th class="right">Hours</th>
              <th class="right">Rate</th>
              <th class="right">Pay</th>
            </tr>
          </thead>
          <tbody id="rows">
            <tr><td colspan="7" style="color: rgba(159,176,208,0.75);">No data loaded yet.</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

<script>
  const $ = (id) => document.getElementById(id);

  function setMsg(text, ok) {
    const el = $("msg");
    el.textContent = text || "";
    el.className = "msg " + (text ? (ok ? "ok" : "bad") : "");
  }

  function encodeForm(obj) {
    const p = new URLSearchParams();
    for (const [k,v] of Object.entries(obj)) p.set(k, v);
    return p.toString();
  }

  async function apiMonth(year, month) {
    const r = await fetch(`/api/month?year=${encodeURIComponent(year)}&month=${encodeURIComponent(month)}`);
    const t = await r.text();
    let j;
    try { j = JSON.parse(t); } catch { throw new Error("Bad JSON from server"); }
    if (!r.ok || !j.ok) throw new Error(j.error || `HTTP ${r.status}`);
    return j;
  }

  async function apiSaveEntry(data) {
    const r = await fetch("/api/entry", {
      method: "POST",
      headers: {"Content-Type":"application/x-www-form-urlencoded"},
      body: encodeForm(data),
    });
    const t = await r.text();
    let j;
    try { j = JSON.parse(t); } catch { throw new Error("Bad JSON from server"); }
    if (!r.ok || !j.ok) throw new Error(j.error || `HTTP ${r.status}`);
    return j;
  }

  async function apiDelete(date) {
    const r = await fetch(`/api/entry?date=${encodeURIComponent(date)}`, { method: "DELETE" });
    const t = await r.text();
    let j;
    try { j = JSON.parse(t); } catch { throw new Error("Bad JSON from server"); }
    if (!r.ok || !j.ok) throw new Error(j.error || `HTTP ${r.status}`);
    return j;
  }

  function renderMonth(j) {
    $("t_minutes").textContent = `Minutes: ${j.totals.minutes}`;
    $("t_hours").textContent = `Hours: ${Number(j.totals.hours).toFixed(2)}`;
    $("t_pay").textContent = `Pay: ${Number(j.totals.pay).toFixed(2)}`;

    const body = $("rows");
    body.innerHTML = "";

    if (!j.entries || j.entries.length === 0) {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td colspan="7" style="color: rgba(159,176,208,0.75);">No entries for this month.</td>`;
      body.appendChild(tr);
      return;
    }

    for (const e of j.entries) {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><button style="padding:6px 8px" title="Load into form">${e.date}</button></td>
        <td>${e.start}</td>
        <td>${e.end}</td>
        <td class="right">${e.break_min}</td>
        <td class="right">${Number(e.hours).toFixed(2)}</td>
        <td class="right">${Number(e.rate).toFixed(2)}</td>
        <td class="right">${Number(e.pay).toFixed(2)}</td>
      `;
      tr.querySelector("button").addEventListener("click", () => {
        $("date").value = e.date;
        $("start").value = e.start;
        $("end").value = e.end;
        $("break_min").value = e.break_min;
        $("rate").value = Number(e.rate).toFixed(2);
        setMsg(`Loaded ${e.date} into the form.`, true);
      });
      body.appendChild(tr);
    }
  }

  async function refresh() {
    setMsg("", true);
    const year = parseInt($("year").value, 10);
    const month = parseInt($("month").value, 10);
    try {
      const j = await apiMonth(year, month);
      renderMonth(j);
    } catch (e) {
      setMsg(e.message || String(e), false);
    }
  }

  function initDefaults() {
    const now = new Date();
    $("year").value = now.getFullYear();
    $("month").value = String(now.getMonth() + 1);

    // default date = today
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, "0");
    const dd = String(now.getDate()).padStart(2, "0");
    $("date").value = `${yyyy}-${mm}-${dd}`;
  }

  $("refresh").addEventListener("click", refresh);

  $("save").addEventListener("click", async () => {
    setMsg("", true);
    const date = $("date").value;
    const start = $("start").value;
    const end = $("end").value;
    const break_min = $("break_min").value || "0";
    const rate = $("rate").value;

    try {
      await apiSaveEntry({ date, start, end, break_min, rate });
      setMsg("Saved.", true);
      await refresh();
    } catch (e) {
      setMsg(e.message || String(e), false);
    }
  });

  $("del").addEventListener("click", async () => {
    setMsg("", true);
    const date = $("date").value;
    if (!date) { setMsg("Pick a date first.", false); return; }
    try {
      await apiDelete(date);
      setMsg("Deleted (if it existed).", true);
      await refresh();
    } catch (e) {
      setMsg(e.message || String(e), false);
    }
  });

  initDefaults();
  refresh();
</script>
</body>
</html>
)HTML";

    res.set_content(page, "text/html; charset=utf-8"); });

    svr.Get("/api/month", [](const Request &req, Response &res)
            {
        std::string err;
        int year = 0, month = 0;

        if (!req.has_param("year") || !req.has_param("month")) 
        {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"Missing year/month\"}", "application/json");

            return;
        }

        try 
        {
            year = std::stoi(req.get_param_value("year"));
            month = std::stoi(req.get_param_value("month"));
        } 
        
        catch (...) 
        {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"Invalid year/month\"}", "application/json");
            return;
        }

        if (year < 1900 || year > 3000 || month < 1 || month > 12) {
            res.status = 400;
            res.set_content("{\"ok\":false,\"error\":\"year/month out of range\"}", "application/json");
            return;
        }

        std::ostringstream prefix;
        prefix << std::setw(4) << std::setfill('0') << year<< "-" << std::setw(2) << std::setfill('0') << month<< "-";
        const std::string pre = prefix.str();

        struct DayRow 
        {
            std::string date;
            Entry e;
            int minutes = 0;
            double hours = 0.0;
            double pay = 0.0;
        };

        std::vector<DayRow> rows;
        double total_hours = 0.0;
        double total_pay = 0.0;
        int total_minutes = 0;

        {
            std::lock_guard<std::mutex> lk(g_mu);
            rows.reserve(g_entries.size());
            for (const auto& kv : g_entries) 
            {
                if (kv.first.rfind(pre, 0) != 0) {continue;} // not this month
                DayRow r;
                r.date = kv.first;
                r.e = kv.second;
                r.minutes = work_minutes(r.e);
                r.hours = r.minutes / 60.0;
                r.pay = round2(r.hours * r.e.rate);

                total_minutes += r.minutes;
                total_hours += r.hours;
                total_pay += r.pay;

                rows.push_back(r);
            }
        }

        std::sort(rows.begin(), rows.end(), [](const DayRow& a, const DayRow& b) 
        {
            return a.date < b.date;
        });

        std::ostringstream json;
        json << "{"
             << "\"ok\":true,"
             << "\"year\":" << year << ","
             << "\"month\":" << month << ","
             << "\"totals\":{"
             <<   "\"minutes\":" << total_minutes << ","
             <<   "\"hours\":" << std::fixed << std::setprecision(2) << round2(total_hours) << ","
             <<   "\"pay\":" << std::fixed << std::setprecision(2) << round2(total_pay)
             << "},"
             << "\"entries\":[";

        for (size_t i = 0; i < rows.size(); i++) 
        {
            const auto& r = rows[i];
            if (i) json << ",";
            json << "{"
                 << "\"date\":\"" << json_escape(r.date) << "\","
                 << "\"start\":\"" << json_escape(minutes_to_hhmm(r.e.start_min)) << "\","
                 << "\"end\":\"" << json_escape(minutes_to_hhmm(r.e.end_min)) << "\","
                 << "\"break_min\":" << r.e.break_min << ","
                 << "\"minutes_worked\":" << r.minutes << ","
                 << "\"hours\":" << std::fixed << std::setprecision(2) << round2(r.hours) << ","
                 << "\"rate\":" << std::fixed << std::setprecision(2) << round2(r.e.rate) << ","
                 << "\"pay\":" << std::fixed << std::setprecision(2) << r.pay
                 << "}";
        }
        json << "]}";

        res.set_content(json.str(), "application/json"); });

    cout << "Open http://localhost:8080\n";

    if (!svr.listen("0.0.0.0", 8080))
    {
        cerr << "ERROR: listen() failed on 0.0.0.0:8080 (port in use? no permission?)\n";
        return 1;
    }

    return 0;
}