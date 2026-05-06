module ApplicationHelper
  def flash_bootstrap_class(type)
    { "notice" => "success", "alert" => "danger", "info" => "info", "warning" => "warning" }
      .fetch(type.to_s, "secondary")
  end

  def sort_link(column, label, current_col, current_dir)
    new_dir = (current_col == column && current_dir == "desc") ? "asc" : "desc"
    icon = current_col == column ? (current_dir == "asc" ? " ▲" : " ▼") : ""
    link_to "#{label}#{icon}", request.path + "?sort=#{column}&dir=#{new_dir}", class: "text-white text-decoration-none"
  end
end
