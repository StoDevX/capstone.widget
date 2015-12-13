command: 'curl --silent https://www.stolaf.edu/people/olaf/capstone15/Rives.html'
refreshFrequency: 60000

style: '''
	top: 28px
	left: 3px
	font-family: Source Code Pro
	font-size: 11px
	-webkit-font-smoothing: antialiased

	.block
		padding: 4px 6px
		background-color: rgba(black, 0.5)
		color: white

	.active
		background-color: rgba(red, 0.75)
		color: white

	time
		font-weight: bold
	.active time
		font-weight: normal


	.danger
		color: red
	.active .danger
		color: inherit
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
	hours = if negative then Math.ceil(minutes / 60) else Math.floor(minutes / 60)
	result = "#{minutes % 60}m"
	if hours
		result = "#{hours}h #{result}"
	return result


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


getRemainingQuota: (html) ->
	quota = 77 * 7
	workedThisWeek = @getWorkedThisWeekRaw(html)
	margin = @getMarginRaw(html)
	remainingTime = quota - workedThisWeek - margin
	if (remainingTime < 0) then (remainingTime = 0)
	return @prettifyMinutes(remainingTime)


isTimerActive: (html) ->
	cell = html.querySelector('.table tbody tr:first-child td:first-child')
	inProgressRegex = /In Progress/i
	isInProgress = inProgressRegex.test(cell.textContent)


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
	start = 4.0
	per = 1/15
	for i in [0...numberDown]
		start -= per

	return Number((start * 25).toFixed(2))


render: (result) ->
	parser = new DOMParser()
	html = parser.parseFromString(result, 'text/html')

	content = [
		"<time>#{@getHoursWorked(html)}</time> logged",
		"<time>#{@getMargin(html)}</time> of margin",
		"<time>#{@countBadGradeDays(html)}</time> days < quota",
		"<time>#{@calculateGrade(html)}%</time> at best",
		# "<time>#{@getWorkedThisWeek(html)}</time> worked",
		# "<time>#{@getRemainingQuota(html)}</time> remaining",
	].join(' | ')

	isInProgress = @isTimerActive(html)
	classname = if isInProgress then 'active' else ''
	timer = ''
	if isInProgress
		timer = "<b>TIMER ACTIVE (#{@getTimerTime(html)})</b> | "

	return "<div class='block #{classname}'>Capstone: #{timer} #{content}</div>"
