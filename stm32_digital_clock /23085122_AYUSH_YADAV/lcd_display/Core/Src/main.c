/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Digital Clock with RTC, Alarm, and Stopwatch
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  ******************************************************************************
  */

#include "main.h"
#include "lcd8.h"
#include "string.h"
#include <stdio.h>

/* Private variables ---------------------------------------------------------*/
RTC_HandleTypeDef hrtc;

// Time and alarm structures
RTC_TimeTypeDef sTime;
RTC_AlarmTypeDef sAlarm;
RTC_DateTypeDef sDate;

// Display buffers
char time_buffer[20];
char alarm_buffer[20];
char stopwatch_buffer[20];

// State flags
int format_flag = 0;        // 0 = 24-hour, 1 = 12-hour
int alarm_flag = 0;         // 0 = alarm off, 1 = alarm on
int alarm_triggered = 0;    // Flag to prevent continuous alarm triggering

// Stopwatch variables
RTC_TimeTypeDef sw_time = {0};
int sw_running = 0;
uint32_t sw_last_tick = 0;

// Button debouncing
typedef struct {
    GPIO_TypeDef* port;
    uint16_t pin;
    int last_state;
    uint32_t last_press_time;
} Button_t;

Button_t format_btn = {GPIOB, GPIO_PIN_2, 0, 0};
Button_t alarm_btn = {GPIOB, GPIO_PIN_10, 0, 0};
Button_t sw_stop_btn = {SW_STOP_GPIO_Port, SW_STOP_Pin, 0, 0};
Button_t sw_restart_btn = {SW_RESTART_GPIO_Port, SW_RESTART_Pin, 0, 0};

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_RTC_Init(void);

// Application functions
void display_time(void);
void handle_alarm(void);
void handle_stopwatch(void);
void handle_buttons(void);
int is_button_pressed(Button_t* btn);
void format_time_string(int hours, int minutes, int seconds, char* buffer, int use_12hr);

/* Private user code ---------------------------------------------------------*/

/**
 * @brief Format time into string with 12/24 hour support
 */
void format_time_string(int hours, int minutes, int seconds, char* buffer, int use_12hr) {
    if (use_12hr) {
        char period[] = "AM";
        int display_hour = hours;
        
        if (hours >= 12) {
            strcpy(period, "PM");
            if (hours > 12) display_hour = hours - 12;
        } else if (hours == 0) {
            display_hour = 12; // Midnight case
        }
        
        sprintf(buffer, "%02d:%02d:%02d %s", display_hour, minutes, seconds, period);
    } else {
        sprintf(buffer, "%02d:%02d:%02d", hours, minutes, seconds);
    }
}

/**
 * @brief Display current time on LCD
 */
void display_time(void) {
    // Get current time and date
    HAL_RTC_GetTime(&hrtc, &sTime, RTC_FORMAT_BIN);
    HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN); // Required to unlock shadow registers
    
    // Format and display time
    lcdSetCursor(0, 0);
    format_time_string(sTime.Hours, sTime.Minutes, sTime.Seconds, time_buffer, format_flag);
    lcdString(time_buffer);
}

/**
 * @brief Handle alarm functionality
 */
void handle_alarm(void) {
    if (!alarm_flag) {
        alarm_triggered = 0; // Reset alarm trigger when alarm is disabled
        return;
    }
    
    // Display alarm time on second line
    lcdSetCursor(1, 0);
    HAL_RTC_GetAlarm(&hrtc, &sAlarm, RTC_ALARM_A, RTC_FORMAT_BIN);
    format_time_string(sAlarm.AlarmTime.Hours, sAlarm.AlarmTime.Minutes, 
                      sAlarm.AlarmTime.Seconds, alarm_buffer, format_flag);
    lcdString(alarm_buffer);
    
    // Check if alarm should trigger
    if (!alarm_triggered && 
        sTime.Hours == sAlarm.AlarmTime.Hours &&
        sTime.Minutes == sAlarm.AlarmTime.Minutes &&
        sTime.Seconds == sAlarm.AlarmTime.Seconds) {
        
        alarm_triggered = 1;
        HAL_GPIO_WritePin(ALARM_GPIO_Port, ALARM_Pin, GPIO_PIN_SET);
        
        // Use a non-blocking approach for alarm duration
        // In a real implementation, you might want to use a timer for this
    }
    
    // Turn off alarm after some time (this is a simplified approach)
    static uint32_t alarm_start_time = 0;
    if (alarm_triggered) {
        if (alarm_start_time == 0) {
            alarm_start_time = HAL_GetTick();
        } else if (HAL_GetTick() - alarm_start_time > 2000) { // 2 seconds
            HAL_GPIO_WritePin(ALARM_GPIO_Port, ALARM_Pin, GPIO_PIN_RESET);
            alarm_start_time = 0;
            alarm_triggered = 0;
        }
    }
}

/**
 * @brief Handle stopwatch functionality
 */
void handle_stopwatch(void) {
    // Update stopwatch time if running
    if (sw_running) {
        uint32_t current_tick = HAL_GetTick();
        if (current_tick - sw_last_tick >= 1000) { // 1 second elapsed
            sw_last_tick = current_tick;
            
            sw_time.Seconds++;
            if (sw_time.Seconds >= 60) {
                sw_time.Seconds = 0;
                sw_time.Minutes++;
                if (sw_time.Minutes >= 60) {
                    sw_time.Minutes = 0;
                    sw_time.Hours++;
                    if (sw_time.Hours >= 24) { // Prevent overflow
                        sw_time.Hours = 0;
                    }
                }
            }
        }
    }
    
    // Display stopwatch on third line
    lcdSetCursor(2, 0);
    sprintf(stopwatch_buffer, "SW:%02d:%02d:%02d", sw_time.Hours, sw_time.Minutes, sw_time.Seconds);
    lcdString(stopwatch_buffer);
}

/**
 * @brief Check if button is pressed with debouncing
 */
int is_button_pressed(Button_t* btn) {
    int current_state = HAL_GPIO_ReadPin(btn->port, btn->pin);
    uint32_t current_time = HAL_GetTick();
    
    // Check for rising edge with debouncing
    if (current_state == GPIO_PIN_SET && 
        btn->last_state == GPIO_PIN_RESET && 
        (current_time - btn->last_press_time) > 200) { // 200ms debounce
        
        btn->last_press_time = current_time;
        btn->last_state = current_state;
        return 1;
    }
    
    btn->last_state = current_state;
    return 0;
}

/**
 * @brief Handle all button inputs
 */
void handle_buttons(void) {
    // Format toggle button
    if (is_button_pressed(&format_btn)) {
        format_flag ^= 1; // Toggle between 12/24 hour format
    }
    
    // Alarm on/off button
    if (is_button_pressed(&alarm_btn)) {
        alarm_flag ^= 1; // Toggle alarm display and functionality
        if (!alarm_flag) {
            // Clear alarm display line when disabled
            lcdSetCursor(1, 0);
            lcdString("            "); // Clear line
        }
    }
    
    // Stopwatch start/stop button
    if (is_button_pressed(&sw_stop_btn)) {
        if (!sw_running) {
            sw_last_tick = HAL_GetTick(); // Initialize tick counter
        }
        sw_running = !sw_running; // Toggle stopwatch state
    }
    
    // Stopwatch reset button
    if (is_button_pressed(&sw_restart_btn)) {
        sw_time.Hours = 0;
        sw_time.Minutes = 0;
        sw_time.Seconds = 0;
        sw_running = 0; // Stop the stopwatch
        sw_last_tick = 0;
    }
}

/**
 * @brief  The application entry point.
 * @retval int
 */
int main(void) {
    /* MCU Configuration--------------------------------------------------------*/
    HAL_Init();
    SystemClock_Config();
    
    /* Initialize all configured peripherals */
    MX_GPIO_Init();
    MX_RTC_Init();
    
    /* Initialize LCD */
    lcdSetup(GPIOA, GPIO_PIN_8, GPIO_PIN_9, GPIO_PIN_0, GPIO_PIN_1, 
             GPIO_PIN_2, GPIO_PIN_3, GPIO_PIN_4, GPIO_PIN_5, GPIO_PIN_6, GPIO_PIN_7);
    lcdInit();
    
    /* Clear LCD and show startup message */
    lcdSetCursor(0, 0);
    lcdString("Digital Clock");
    HAL_Delay(2000);
    
    /* Main application loop */
    while (1) {
        handle_buttons();     // Process button inputs
        display_time();       // Update time display
        handle_alarm();       // Handle alarm functionality
        handle_stopwatch();   // Update stopwatch
        
        HAL_Delay(50);        // Small delay to prevent overwhelming the system
    }
}

/**
 * @brief System Clock Configuration
 * @retval None
 */
void SystemClock_Config(void) {
    RCC_OscInitTypeDef RCC_OscInitStruct = {0};
    RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};
    RCC_PeriphCLKInitTypeDef PeriphClkInit = {0};

    /** Initializes the RCC Oscillators according to the specified parameters */
    RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI|RCC_OSCILLATORTYPE_LSI;
    RCC_OscInitStruct.HSIState = RCC_HSI_ON;
    RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
    RCC_OscInitStruct.LSIState = RCC_LSI_ON;
    RCC_OscInitStruct.PLL.PLLState = RCC_PLL_NONE;
    if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK) {
        Error_Handler();
    }

    /** Initializes the CPU, AHB and APB buses clocks */
    RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                                |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
    RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_HSI;
    RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
    RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
    RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

    if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_0) != HAL_OK) {
        Error_Handler();
    }
    
    PeriphClkInit.PeriphClockSelection = RCC_PERIPHCLK_RTC;
    PeriphClkInit.RTCClockSelection = RCC_RTCCLKSOURCE_LSI;
    if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInit) != HAL_OK) {
        Error_Handler();
    }
}

/**
 * @brief RTC Initialization Function
 * @param None
 * @retval None
 */
static void MX_RTC_Init(void) {
    RTC_TimeTypeDef sTime = {0};
    RTC_DateTypeDef DateToUpdate = {0};
    RTC_AlarmTypeDef sAlarm = {0};

    /** Initialize RTC Only */
    hrtc.Instance = RTC;
    hrtc.Init.AsynchPrediv = RTC_AUTO_1_SECOND;
    hrtc.Init.OutPut = RTC_OUTPUTSOURCE_ALARM;
    if (HAL_RTC_Init(&hrtc) != HAL_OK) {
        Error_Handler();
    }

    /** Initialize RTC and set the Time and Date */
    sTime.Hours = 0x14;     // 20:00 (8 PM)
    sTime.Minutes = 0x15;   // 21:15 (8:15 PM)
    sTime.Seconds = 0x10;   // 16 seconds

    if (HAL_RTC_SetTime(&hrtc, &sTime, RTC_FORMAT_BCD) != HAL_OK) {
        Error_Handler();
    }
    
    DateToUpdate.WeekDay = RTC_WEEKDAY_MONDAY;
    DateToUpdate.Month = RTC_MONTH_JANUARY;
    DateToUpdate.Date = 0x29;   // 29th
    DateToUpdate.Year = 0x25;   // 2025

    if (HAL_RTC_SetDate(&hrtc, &DateToUpdate, RTC_FORMAT_BCD) != HAL_OK) {
        Error_Handler();
    }

    /** Enable the Alarm A */
    sAlarm.AlarmTime.Hours = 0x14;   // 20:17 (8:17 PM)
    sAlarm.AlarmTime.Minutes = 0x17;
    sAlarm.AlarmTime.Seconds = 0x0;
    sAlarm.Alarm = RTC_ALARM_A;
    if (HAL_RTC_SetAlarm(&hrtc, &sAlarm, RTC_FORMAT_BCD) != HAL_OK) {
        Error_Handler();
    }
}

/**
 * @brief GPIO Initialization Function
 * @param None
 * @retval None
 */
static void MX_GPIO_Init(void) {
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    /* GPIO Ports Clock Enable */
    __HAL_RCC_GPIOC_CLK_ENABLE();
    __HAL_RCC_GPIOD_CLK_ENABLE();
    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOB_CLK_ENABLE();

    /*Configure GPIO pin Output Level */
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_3
                            |GPIO_PIN_4|GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7
                            |GPIO_PIN_8|GPIO_PIN_9, GPIO_PIN_RESET);

    /*Configure GPIO pin Output Level */
    HAL_GPIO_WritePin(ALARM_GPIO_Port, ALARM_Pin, GPIO_PIN_RESET);

    /*Configure GPIO pins for LCD */
    GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_3
                            |GPIO_PIN_4|GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7
                            |GPIO_PIN_8|GPIO_PIN_9;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

    /*Configure GPIO pin for Alarm output */
    GPIO_InitStruct.Pin = ALARM_Pin;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(ALARM_GPIO_Port, &GPIO_InitStruct);

    /*Configure GPIO pins for buttons */
    GPIO_InitStruct.Pin = FORMAT_Pin|ALARM_ON_Pin|SW_RESTART_Pin|SW_STOP_Pin;
    GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
    GPIO_InitStruct.Pull = GPIO_PULLDOWN;
    HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

    /*Configure additional input pins */
    GPIO_InitStruct.Pin = riya_set_Pin;
    GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(riya_set_GPIO_Port, &GPIO_InitStruct);

    GPIO_InitStruct.Pin = GPIO_PIN_11;
    GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);
}

/**
 * @brief  This function is executed in case of error occurrence.
 * @retval None
 */
void Error_Handler(void) {
    __disable_irq();
    while (1) {
        // Error state - could toggle an LED here for debugging
    }
}

#ifdef USE_FULL_ASSERT
void assert_failed(uint8_t *file, uint32_t line) {
    /* User can add implementation to report the file name and line number */
}
#endif
