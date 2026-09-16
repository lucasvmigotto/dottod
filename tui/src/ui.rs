use crate::app::{App, Mode, Pane};
use crate::state::TaskStatus;
use ratatui::{
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph},
    Frame,
};

pub fn draw(frame: &mut Frame<'_>, app: &mut App) {
    match app.mode {
        Mode::Identity => {
            draw_main(frame, app);
            draw_identity_overlay(frame, app);
        }
        Mode::Summary => {
            draw_main(frame, app);
            draw_summary_overlay(frame, app);
        }
        Mode::Selection | Mode::Running => draw_main(frame, app),
    }
}

fn draw_main(frame: &mut Frame<'_>, app: &mut App) {
    let area = frame.area();
    let chunks = Layout::vertical([Constraint::Min(3), Constraint::Length(1)]).split(area);
    let main = chunks[0];
    let status_area = chunks[1];

    let panes =
        Layout::horizontal([Constraint::Percentage(40), Constraint::Percentage(60)]).split(main);
    draw_list(frame, app, panes[0]);
    draw_log(frame, app, panes[1]);
    draw_status_bar(frame, app, status_area);
}

fn draw_list(frame: &mut Frame<'_>, app: &mut App, area: Rect) {
    let visible = app.visible_tasks();
    let items: Vec<ListItem> = visible
        .iter()
        .map(|&i| {
            let task = &app.tasks[i];
            let checkbox = if app.selected[i] { "[x]" } else { "[ ]" };
            let status = status_span(app.status_of(&task.id), app.tick);
            let desc = task.description.clone();
            let style = if app.focus == Pane::List {
                Style::default()
            } else {
                Style::default().fg(Color::DarkGray)
            };
            ListItem::new(Line::from(vec![
                Span::raw(checkbox),
                Span::raw(" "),
                status,
                Span::raw(" "),
                Span::styled(desc, style),
            ]))
        })
        .collect();

    let list = List::new(items)
        .block(Block::default().title(" Tasks ").borders(Borders::ALL))
        .highlight_style(Style::default().add_modifier(Modifier::REVERSED));
    let mut state = ListState::default();
    state.select(Some(app.cursor));
    frame.render_stateful_widget(list, area, &mut state);
}

fn draw_log(frame: &mut Frame<'_>, app: &mut App, area: Rect) {
    let lines: Vec<Line> = app.logs_for_render().into_iter().map(Line::from).collect();
    let title = if app.focus == Pane::Log {
        " Log * "
    } else {
        " Log "
    };
    let paragraph = Paragraph::new(Text::from(lines))
        .block(Block::default().title(title).borders(Borders::ALL))
        .scroll((app.log_scroll as u16, 0));
    frame.render_widget(paragraph, area);
}

fn draw_status_bar(frame: &mut Frame<'_>, app: &mut App, area: Rect) {
    let selected = app.selected.iter().filter(|s| **s).count();
    let done = app
        .results
        .values()
        .filter(|s| {
            matches!(
                s,
                TaskStatus::Passed | TaskStatus::Failed | TaskStatus::Skipped
            )
        })
        .count();
    let mode = match app.mode {
        Mode::Selection => "selection",
        Mode::Identity => "identity",
        Mode::Running => "running",
        Mode::Summary => "summary",
    };
    let text = format!(
        " {mode} | {selected}/{total} selected | {done}/{total} done | runtime:{runtime} | j/k move · Space toggle · u UI · e runtime · Tab pane · Enter run · q quit ",
        total = app.tasks.len(),
        runtime = app.runtime,
    );
    let paragraph = Paragraph::new(text).style(Style::default().fg(Color::Black).bg(Color::Cyan));
    frame.render_widget(paragraph, area);
}

fn draw_identity_overlay(frame: &mut Frame<'_>, app: &mut App) {
    let area = centered_rect(60, 40, frame.area());
    frame.render_widget(Clear, area);

    let chunks = Layout::vertical([
        Constraint::Length(3),
        Constraint::Length(3),
        Constraint::Length(1),
        Constraint::Length(2),
    ])
    .split(area);

    let name_style = if !app.identity.current {
        Style::default().fg(Color::Yellow)
    } else {
        Style::default()
    };
    let email_style = if app.identity.current {
        Style::default().fg(Color::Yellow)
    } else {
        Style::default()
    };

    let name_label = format!(
        "Git user.name: {}{}",
        app.identity.name,
        if !app.identity.current { "▌" } else { "" }
    );
    let email_label = format!(
        "Git user.email: {}{}",
        app.identity.email,
        if app.identity.current { "▌" } else { "" }
    );

    frame.render_widget(
        Paragraph::new(name_label).block(
            Block::default()
                .title(" Git identity ")
                .borders(Borders::ALL)
                .style(name_style),
        ),
        chunks[0],
    );
    frame.render_widget(
        Paragraph::new(email_label)
            .block(Block::default().borders(Borders::ALL).style(email_style)),
        chunks[1],
    );
    frame.render_widget(Paragraph::new(""), chunks[2]);
    frame.render_widget(
        Paragraph::new("Enter next · Tab switch · Esc cancel"),
        chunks[3],
    );
}

fn draw_summary_overlay(frame: &mut Frame<'_>, app: &mut App) {
    let area = centered_rect(60, 60, frame.area());
    frame.render_widget(Clear, area);

    let mut lines: Vec<Line> = vec![Line::from("Run complete")];
    for task in &app.tasks {
        let status = app.status_of(&task.id);
        lines.push(Line::from(vec![
            status_span(status, app.tick),
            Span::raw(format!("  {}", task.id)),
        ]));
    }
    lines.push(Line::from(""));
    lines.push(Line::from(
        "r rerun failures · Enter back to selection · q quit",
    ));

    let paragraph =
        Paragraph::new(lines).block(Block::default().title(" Summary ").borders(Borders::ALL));
    frame.render_widget(paragraph, area);
}

fn status_span(status: TaskStatus, tick: u64) -> Span<'static> {
    match status {
        TaskStatus::Pending => Span::styled("·", Style::default().fg(Color::DarkGray)),
        TaskStatus::Running => Span::styled(spinner(tick), Style::default().fg(Color::Yellow)),
        TaskStatus::Passed => Span::styled("✔", Style::default().fg(Color::Green)),
        TaskStatus::Failed => Span::styled("✗", Style::default().fg(Color::Red)),
        TaskStatus::Skipped => Span::styled("—", Style::default().fg(Color::DarkGray)),
    }
}

fn spinner(tick: u64) -> &'static str {
    const FRAMES: [&str; 10] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
    FRAMES[(tick as usize) % FRAMES.len()]
}

fn centered_rect(percent_x: u16, percent_y: u16, area: Rect) -> Rect {
    let vertical = Layout::vertical([
        Constraint::Percentage((100 - percent_y) / 2),
        Constraint::Percentage(percent_y),
        Constraint::Percentage((100 - percent_y) / 2),
    ])
    .split(area);
    let horizontal = Layout::horizontal([
        Constraint::Percentage((100 - percent_x) / 2),
        Constraint::Percentage(percent_x),
        Constraint::Percentage((100 - percent_x) / 2),
    ])
    .split(vertical[1]);
    horizontal[1]
}
