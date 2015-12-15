command: 'bash capstone.widget/get-pages.sh'
refreshFrequency: 900000

style: '''
	top: 120px
	left: 3px

	column-padding = 0.85em
	column-border = solid 1px rgba(black, 0.15)

	-webkit-font-smoothing: antialiased
	font-family: Source Code Pro
	font-size: 10px
	line-height: 1
	box-shadow: 0 0 10px rgba(black, 0.25)
	padding: column-padding
	background-color: rgba(white, 0.65)
	-webkit-backdrop-filter: blur(10px) saturate(150%)

	table
		border-collapse: collapse

	tbody tr:nth-child(odd)
		background-color: rgba(white, 0.35)

	th
		border-bottom: column-border
		font-weight: normal

	td, th
		padding-left: column-padding
		padding-right: column-padding
		border-right: column-border

	td:last-child, th:last-child
		border-right: none

	.block
		padding: 4px 6px
		color: rgba(black, 0.85)

	.active
		font-weight: bold

	.active strong
		font-weight: normal

	.danger
		color: rgba(red, 0.85)

	.name
		text-align: right
	.data
		text-align: center
'''


parseTime: (timestring) ->
	negative = timestring && timestring[0] == '-'

	hours = /(\d+)h/.exec(timestring)
	hours = if hours then Number(hours[1]) else 0
	minutes = /(\d+)m/.exec(timestring)
	minutes = if minutes then Number(minutes[1]) else 0

	total = minutes + (hours * 60)

	if negative
		total *= -1

	return total


prettifyMinutes: (minutes) ->
	negative = minutes < 0
	hourSlot = if negative then Math.ceil(minutes / 60) else Math.floor(minutes / 60)
	minuteSlot = minutes % 60
	result = if hourSlot then "#{hourSlot}h #{minuteSlot}m" else "#{minuteSlot}m"
	return result.trim()


sumListOfTimestrings: (timestrings) ->
	minutes = 0
	for amount in (@parseTime(timestring) for timestring in timestrings)
		minutes += amount
	return minutes


getHoursWorked: (html) ->
	table = html.querySelectorAll('.table')[1]
	cells = table.querySelectorAll('tbody tr td:last-child')
	timestrings = (cell.textContent for cell in cells)
	minutes = @sumListOfTimestrings(timestrings)

	return @prettifyMinutes(minutes)


getMarginRaw: (html) ->
	timestring = html.querySelector('h5 > span').textContent
	return @parseTime(timestring)


getMargin: (html) ->
	margin = @getMarginRaw(html)
	return "<span class='#{if margin < 0 then 'danger' else ''}'>#{@prettifyMinutes(margin)}</span>"


getWorkedThisWeekRaw: (html) ->
	table = html.querySelectorAll('.table')[1]
	cells = Array.prototype.slice.call(table.querySelectorAll('tbody tr:last-child td'))[1...-1]

	timestrings = (cell.innerText.split('\n')[0] for cell in cells)
	minutes = @sumListOfTimestrings(timestrings)

	return minutes


getWorkedThisWeek: (html) ->
	return @prettifyMinutes(@getWorkedThisWeekRaw(html))


getTimeNeededForQuota: (html) ->
	quota = 77 * 7
	workedThisWeek = @getWorkedThisWeekRaw(html)
	margin = @getMarginRaw(html)
	remainingTime = quota - workedThisWeek - margin
	if (remainingTime < 0) then (remainingTime = 0)
	return @prettifyMinutes(remainingTime)


isTimerActive: (html) ->
	cell = html.querySelector('.table tbody tr:first-child td:first-child')
	inProgressRegex = /in progress/i
	isInProgress = inProgressRegex.test(cell.textContent)
	return isInProgress


getTimerTimeRaw: (html) ->
	since = html.querySelector('.table tbody tr:first-child td:first-child').innerText.split('\n')[1]
	# Dec 09 06:03PM
	regex = /([a-z]{3}) +(\d{2}) +(\d{2}):(\d{2})(AM|PM)/i
	[_, month, day, hour, minute, ampm] = since.match(regex)

	date = new Date()
	date.setDate(Number(day))
	date.setHours(if ampm == 'PM' and hour != '12' then Number(hour) + 12 else Number(hour))
	date.setMinutes(Number(minute))

	return date


getTimerTimeWellDone: (html) ->
	time = @getTimerTimeRaw(html)

	now = Date.now()
	diff = time - now
	minutes = Math.round((diff / 1000 / 60) * -1)

	return minutes


getTimerTime: (html) ->
	return @prettifyMinutes(@getTimerTimeWellDone(html))


countBadGradeDays: (html) ->
	return html.querySelectorAll('.table .danger').length


calculateGrade: (html) ->
	numberDown = @countBadGradeDays(html)
	start = 100
	per = 1/15
	step = 10

	return Number(start - (per * numberDown * step)).toFixed(2)

letterGrade: (gradeString) ->
	grade = Number(gradeString)
	if grade < 60
		return 'F'
	if grade < 70
		return 'D'
	if grade < 80
		return 'C'
	if grade < 90
		return 'B'
	if grade <= 100
		return 'A'


getDataForWidget: (name, htmlText) ->
	parser = new DOMParser()
	html = parser.parseFromString(htmlText, 'text/html')

	isInProgress = @isTimerActive(html)
	grade = @calculateGrade(html)

	return {
		isActive: isInProgress,
		timer: @getTimerTime(html),
		name: name,
		hoursWorked: @getHoursWorked(html),
		margin: @getMargin(html),
		workedThisWeek: @getWorkedThisWeek(html),
		getTimeNeededForQuota: @getTimeNeededForQuota(html),
		badGradeDays: @countBadGradeDays(html),
		maxGrade: grade,
		letterGrade: @letterGrade(grade)
	}

makeRowFromData: (info) ->
	classname = if info.isActive then 'active' else ''
	timer = if info.isActive then "今 #{info.timer}" else ''

	content = [
		"<td class='name'>#{info.name}</td>",
		"<td class='data'>#{info.hoursWorked} #{timer}</td>",
		"<td class='data'>#{info.margin}</td>",
		"<td class='data'>#{info.workedThisWeek}</td>",
		"<td class='data'>#{info.getTimeNeededForQuota}</td>",
		"<td class='data'>#{info.badGradeDays} days</td>",
		"<td class='data'>#{info.maxGrade}%</td>",
		"<td class='data'>#{info.letterGrade}</td>"
	].join('')

	return "<tr class='block #{classname}'>#{content}</tr>"


render: (result) ->
	text = result.split(/__USER:/)
	text = ([t.match(/\w+/)[0], t] for t in text when t)

	# sortBy = 'badGradeDays'
	sortBy = 'name'
	infos = (@getDataForWidget(n, t) for [n, t] in text)
	infos.sort(`function(a, b){if (a[sortBy] < b[sortBy]) return -1; if (a[sortBy] > b[sortBy]) return 1; return 0}`)
	widgets = infos.map(@makeRowFromData)

	columns = ["Name", "Total", "Margin", "Week", "Pre-Quota", "日 &lt; Quota", "Max Grade", ""]
	headings = "<tr>#{("<th>#{text}</th>" for text in columns).join('')}"
	return "<table><thead>#{headings}</thead><tbody>#{widgets.join('\n')}</tbody></table>"
